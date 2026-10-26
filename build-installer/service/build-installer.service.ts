import { parseArgs, promisify } from 'util';
import { execFile, type ChildProcess } from 'child_process';
import * as childProcess from 'child_process';
import * as fsPromises from 'fs/promises';
import * as path from 'path';

import { parse as parseIni, type IIniObjectSection } from 'js-ini';
import Twig from 'twig';

import { type IGameProfile } from 'cncnet-core/interface/game-profile.interface';
import {
    loadGameProfile,
    resolveGamePackageDir,
} from 'cncnet-core/service/game-profile.service';
import { createContext, installerVersion, type IBuildInstallerContext } from 'build-installer/constants';
import { type TemplateModel } from 'build-installer/class/template-model.class';

const execFileAsync = promisify(execFile);

interface IBuildCommandOptions {
    command: string;
    args: string[];
    cwd: string;
    env?: NodeJS.ProcessEnv;
    /** When true, absolute template-model paths are converted to Z: wine paths */
    useWindowsPaths: boolean;
}

function isIniSection(value: unknown): value is IIniObjectSection {
    return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Escape a value for use inside a Pascal string literal (Inno [Code]). */
function pascalEscape(value: string): string {
    return value.replace(/'/g, "''");
}

export class BuildInstallerService {
    private profile: IGameProfile;
    private context: IBuildInstallerContext;

    public constructor(profile: IGameProfile, workingDir: string) {
        this.profile = profile;
        this.context = createContext(profile, workingDir);
    }

    public static run(): void {
        const { values } = parseArgs({
            options: {
                game: {
                    type: 'string',
                    short: 'g',
                },
                workingDir: {
                    type: 'string',
                    short: 'w',
                },
            },
        });

        if (!values.game) {
            console.error('Missing required argument: --game');
            console.error('Example: npm run build-installer -- --game yr --workingDir /path/to/package');
            process.exit(1);
        }

        const profile = loadGameProfile(values.game);
        const workingDir = resolveGamePackageDir(profile, values.workingDir);

        new BuildInstallerService(profile, workingDir).run().catch((error) => {
            console.error(error instanceof Error ? error.stack ?? error.message : String(error));
            process.exit(1);
        });
    }

    private async run(): Promise<void> {
        await this.checkForRequiredFilesAsync();
        await this.buildMixesIfNeeded();
        const commandOptions = await this.getBuildCommandOptions();
        await this.buildInstallerScript(commandOptions.useWindowsPaths);
        await this.buildInstaller(commandOptions);
    }

    // ------------------------------------------------------------------ Model

    private async buildInstallerScript(useWindowsPaths: boolean): Promise<void> {
        console.log('Building installer script');
        const templateModel = await this.getTemplateModel(useWindowsPaths);
        console.log('Template model:');
        console.log(templateModel);

        // installer.iss is a build artifact, not a source file: prepend a
        // banner telling developers to edit the template instead. (Plain
        // ';' comment lines, so the rendered script stays valid Inno.)
        const generatedBanner = [
            '; =============================================================================',
            '; GENERATED FILE - DO NOT EDIT',
            ';',
            "; This installer.iss was rendered by 'npm run build-installer' from the",
            '; template below. To change it, edit the template (or the game profile in',
            `; games/${this.profile.id}.json) - this file is overwritten on every build.`,
            `;   Template: ${this.context.installerTemplate}`,
            '; =============================================================================',
            '',
        ].join('\n');

        await new Promise<void>((resolvePromise, reject) => {
            Twig.renderFile(this.context.installerTemplate, templateModel, (err, content) => {
                if (err) {
                    reject(err);
                    return;
                }

                fsPromises
                    .writeFile(this.context.installerScript, generatedBanner + content)
                    .then(() => {
                        console.log(`Installer script written to '${this.context.installerScript}'`);
                        resolvePromise();
                    })
                    .catch(reject);
            });
        });
    }

    private async getTemplateModel(useWindowsPaths: boolean): Promise<TemplateModel> {
        const appVersion = await this.getAppVersion();

        const model: TemplateModel = {
            app: {
                name: this.profile.app.name,
                version: appVersion,
                versionName: `${this.profile.app.name} ${appVersion}`,
                publisher: this.profile.app.publisher,
                publisherUrl: this.profile.app.publisherUrl,
                supportUrl: this.profile.app.supportUrl,
                updatesUrl: this.profile.app.updatesUrl,
                description: this.profile.app.description,
                appId: this.profile.app.appId,
            },
            // Absolute package dir: [Setup] SourceDir (YR) or the [Files]
            // source path (`Source: "{{ sourceDir }}\*"`, TS/RA1).
            sourceDir: this.getRuntimePath(this.context.packagePath, useWindowsPaths),
            outputDir: this.getRuntimePath(this.context.outputDir, useWindowsPaths),
            setupIconFile: this.getRuntimePath(this.context.setupIconPath, useWindowsPaths),
            licenseFile: this.getRuntimePath(this.context.licenseFilePath, useWindowsPaths),
            outputBaseFilename: this.profile.output.baseFilename as string,
            // Wizard title: client + installer version, Pascal-escaped here because the app name
            // may contain apostrophes (YR) that would break the [Code] string literal.
            wizardCaption: `Setup - ${pascalEscape(this.profile.app.name)} ${pascalEscape(appVersion)} (Installer ${pascalEscape(installerVersion)})`,
            installDeleteFiles: await this.getInstallDeleteFiles(),
            excludedInstallerFiles: this.profile.excludedFiles,
        };

        // The inno dir as [Setup] SourceDir, for templates that install the
        // package via `Source: "{{ sourceDir }}\*"` (always provided).
        model.innoPath = this.getRuntimePath(this.context.innoPath, useWindowsPaths);

        // Movie download lists: provided whenever the profile declares them.
        if (this.profile.movies) {
            model.movies = this.profile.movies;
        }
        if (this.profile.extraMovies) {
            model.extraMovies = this.profile.extraMovies;
        }

        return model;
    }

    private async getAppVersion(): Promise<string> {
        const spec = this.profile.version;
        const versionContent = await fsPromises.readFile(this.context.versionFilePath, {
            encoding: 'utf-8',
        });

        const versionIni = parseIni(versionContent, {
            autoTyping: false,
        });

        const sectionName = spec.section ?? Object.keys(versionIni)[0];
        const section = sectionName ? versionIni[sectionName] : undefined;

        if (!isIniSection(section) || !(spec.key in section)) {
            if (spec.missing === 'undefined') {
                return 'undefined';
            }

            throw new Error(`Missing ${spec.key} entry in '${this.context.versionFilePath}'`);
        }

        const version = section[spec.key];
        if (typeof version !== 'string') {
            if (spec.missing === 'undefined') {
                return 'undefined';
            }

            throw new Error(`Invalid ${spec.key} value in '${this.context.versionFilePath}'`);
        }

        if (spec.trim) {
            const trimmed = version.trim();
            if (trimmed.length === 0) {
                if (spec.missing === 'undefined') {
                    return 'undefined';
                }

                throw new Error(`Missing ${spec.key} entry in '${this.context.versionFilePath}'`);
            }

            return trimmed;
        }

        return version;
    }

    // -------------------------------------------------------- InstallDelete

    private async getInstallDeleteFiles(): Promise<string[]> {
        const spec = this.profile.installDelete;
        const entries = [
            ...(await this.getUpdateExecEntries(path.resolve(this.context.packagePath, 'preupdateexec'))),
            ...(await this.getUpdateExecEntries(path.resolve(this.context.packagePath, 'updateexec'))),
        ];

        let result = spec.dedupe ? Array.from(new Set(entries)) : entries;

        if (spec.sort) {
            result = [...result].sort((a, b) => {
                if (a === b) {
                    return 0;
                }

                return a > b ? 1 : -1;
            });
        }

        return result;
    }

    private async getUpdateExecEntries(file: string): Promise<string[]> {
        const spec = this.profile.installDelete;
        const content = await fsPromises.readFile(file, { encoding: 'utf-8' });

        let entries: string[];

        if (spec.parser === 'manual') {
            // preupdateexec/updateexec are INI-like but their Delete sections
            // contain bare path lines (no key=value), which generic INI parsers
            // reject, so they are parsed manually.
            entries = this.parseEntriesManual(content, spec.sections);
        } else {
            const ini = parseIni(content, {
                autoTyping: false,
                // tell the parser to read the sections as a list of strings without keys
                dataSections: spec.sections,
            });

            entries = spec.sections.flatMap((section) => {
                const list = ini[section];
                return Array.isArray(list) ? list : [];
            });
        }

        entries = entries.filter(
            (entry) => Boolean(entry) && (spec.sentinel === null || entry !== spec.sentinel),
        );

        if (spec.filterExisting === 'noop-warn') {
            // Keep all entries (Array.filter cannot await an async predicate)
            // and warn, fire-and-forget, about entries that still exist in
            // the package.
            for (const entry of entries) {
                const entryPath = path.resolve(this.context.packagePath, entry);

                fsPromises.access(entryPath)
                    .then(() => {
                        console.warn(
                            `File in '${path.basename(file)}' delete list, but still in repo: '${entryPath}'`,
                        );
                    })
                    .catch(() => undefined);
            }

            return entries;
        }

        if (spec.filterExisting === 'keep-missing') {
            // Keep only entries missing from the package, warn about the ones
            // that still exist.
            const missingEntries: string[] = [];

            await Promise.all(
                entries.map(async (entry) => {
                    const entryPath = path.resolve(this.context.packagePath, entry);

                    try {
                        // if this succeeds, then the file or dir currently exists in the package dir;
                        // it probably shouldn't exist in preupdateexec or updateexec files
                        await fsPromises.access(entryPath);
                        console.warn(
                            `File in '${path.basename(file)}' delete list, but still in repo: '${entryPath}'`,
                        );
                    } catch (error) {
                        missingEntries.push(entry);
                    }
                }),
            );

            return missingEntries;
        }

        return entries;
    }

    private parseEntriesManual(content: string, sections: string[]): string[] {
        const entries: string[] = [];
        let section = '';

        for (const rawLine of content.split(/\r?\n/)) {
            const line = rawLine.trim();

            if (line.length === 0 || line.startsWith(';')) {
                continue;
            }

            if (line.startsWith('[') && line.endsWith(']')) {
                section = line.slice(1, -1).trim();
                continue;
            }

            if (sections.includes(section)) {
                const entry = line.split('=')[0].trim();

                if (entry.length > 0) {
                    entries.push(entry);
                }
            }
        }

        return entries;
    }

    // ---------------------------------------------------------- Required files

    private async checkForRequiredFilesAsync(): Promise<void> {
        const requiredFiles: string[] = [
            ...this.profile.requiredFiles.package.map((entry) => path.resolve(this.context.packagePath, entry)),
            ...this.profile.requiredFiles.inno.map((entry) => path.resolve(this.context.innoPath, entry)),
        ];

        for (const filePath of requiredFiles) {
            try {
                await fsPromises.access(filePath);
            } catch (error) {
                if (filePath.includes('InnoDependencyInstaller')) {
                    throw new Error(
                        `Missing build-installer dependency: '${filePath}'. ` +
                            `Initialize the git submodule at 'build-installer/inno/libs/InnoDependencyInstaller'.`,
                    );
                }

                throw new Error(`Missing required file: '${filePath}'`);
            }
        }
    }

    // ------------------------------------------------------------------ Mixes

    private async buildMixesIfNeeded(): Promise<void> {
        // Runs the game's BuildMixes.ps1 one-shot when the mix output dir is
        // empty. Only enabled per profile (mixes.buildInService); CI is
        // expected to run mix-packer separately.
        if (!this.profile.mixes.buildInService) {
            return;
        }

        const mixDir = path.resolve(this.context.packagePath, this.profile.mixes.outDir);
        const mixFiles = (await fsPromises.readdir(mixDir).catch(() => [] as string[])).filter((file) =>
            file.toLowerCase().endsWith('.mix'),
        );

        if (mixFiles.length > 0) {
            console.log(`MIX archives already present (${mixFiles.length}), skipping MIX build.`);
            return;
        }

        if (process.platform !== 'win32') {
            throw new Error(
                'MIX archives are missing and BuildMixes.ps1 requires Windows.\n' +
                    'Run BuildMixes.bat on Windows before building the installer.',
            );
        }

        const scriptPath = path.resolve(this.context.packagePath, 'Tools', 'BuildMixes.ps1');
        console.log('Building MIX archives (BuildMixes.ps1)...');

        await new Promise<void>((resolvePromise, reject) => {
            const child = childProcess.spawn(
                'powershell.exe',
                ['-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', scriptPath],
                { cwd: this.context.packagePath, stdio: 'inherit' },
            );

            child.on('error', reject);
            child.on('close', (code) => {
                if (code === 0) {
                    resolvePromise();
                    return;
                }

                reject(new Error(`BuildMixes.ps1 exited with code ${code ?? 'unknown'}`));
            });
        });

        const produced = await fsPromises.readdir(mixDir).catch(() => [] as string[]);

        if (produced.length === 0) {
            throw new Error('MIX build finished but no MIX archives were produced.');
        }
    }

    // ------------------------------------------------------------------- ISCC

    private async getBuildCommandOptions(): Promise<IBuildCommandOptions> {
        if (process.platform === 'win32') {
            const installerBinary = await this.resolveInstallerBinary();

            return {
                command: installerBinary,
                args: [this.context.installerScript],
                cwd: path.dirname(installerBinary),
                useWindowsPaths: false,
            };
        }

        if (process.platform === 'linux') {
            return await this.getLinuxBuildCommandOptions();
        }

        throw new Error(`Unsupported platform for build-installer: ${process.platform}`);
    }

    private async resolveInstallerBinary(): Promise<string> {
        // ISCC lookup order: INNO_SETUP_ISCC/ISCC_PATH env var, the vendored inno/bin/ISCC.exe,
        // well-known install paths (Inno 7 and 6), then PATH.
        const candidates: string[] = [];

        const envVar = process.env.INNO_SETUP_ISCC || process.env.ISCC_PATH;
        if (envVar) {
            candidates.push(envVar);
        }

        candidates.push(this.context.installerBinary);

        candidates.push(
            'C:/Program Files/Inno Setup 7/ISCC.exe',
            'C:/Program Files (x86)/Inno Setup 7/ISCC.exe',
            'C:/Program Files/Inno Setup 6/ISCC.exe',
            'C:/Program Files (x86)/Inno Setup 6/ISCC.exe',
        );

        try {
            const { stdout } = await execFileAsync('where', ['ISCC.exe']);
            for (const line of stdout.split(/\r?\n/).map((s) => s.trim()).filter(Boolean)) {
                if (!candidates.includes(line)) {
                    candidates.push(line);
                }
            }
        } catch {
            // no ISCC on PATH - ignore
        }

        for (const candidate of candidates) {
            try {
                await fsPromises.access(candidate);
            } catch {
                continue;
            }

            // Quick sanity check: try to start with '/?' to verify it runs
            const ok = await new Promise<boolean>((resolveCheck) => {
                let settled = false;

                const finish = (result: boolean, kill: boolean): void => {
                    if (settled) {
                        return;
                    }

                    settled = true;

                    if (kill) {
                        try {
                            child.kill();
                        } catch {
                            // ignore
                        }
                    }

                    resolveCheck(result);
                };

                let child: ChildProcess;

                try {
                    child = childProcess.spawn(candidate, ['/?'], { windowsHide: true });
                } catch {
                    resolveCheck(false);
                    return;
                }

                child.on('error', () => finish(false, false));
                child.on('close', () => finish(true, false));
                setTimeout(() => finish(true, true), 4000);
            });

            if (ok) {
                console.log(`Resolved Inno Setup CLI at '${candidate}'.`);
                return candidate;
            }
        }

        const hint = [
            `Checked: ${candidates.join('; ')}`,
            'Set env INNO_SETUP_ISCC to an absolute path to ISCC.exe, or install Inno Setup on the runner',
            'Example Chocolatey: choco install innosetup --yes',
        ].join('\n');

        throw new Error(`Unable to locate a working Inno Setup ISCC.exe.\n${hint}`);
    }

    private async getLinuxBuildCommandOptions(): Promise<IBuildCommandOptions> {
        if (!(await this.isCommandAvailable('wine', ['--version']))) {
            throw new Error('build-installer requires wine on Linux, but it was not found in PATH.');
        }

        await fsPromises.mkdir(this.context.winePrefixPath, { recursive: true });
        console.log(`Running ISCC.exe via wine with local prefix '${this.context.winePrefixPath}'`);

        return {
            command: 'wine',
            args: [
                this.toWinePath(this.context.installerBinary),
                this.toWinePath(this.context.installerScript),
            ],
            cwd: this.context.innoBinPath,
            env: {
                ...process.env,
                WINEDEBUG: '-fixme-all',
                WINEPREFIX: this.context.winePrefixPath,
            },
            useWindowsPaths: true,
        };
    }

    private async isCommandAvailable(command: string, args: string[]): Promise<boolean> {
        return await new Promise((resolvePromise) => {
            const child = childProcess.spawn(command, args, {
                stdio: 'ignore',
            });

            child.on('error', (error) => {
                if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
                    resolvePromise(false);
                    return;
                }

                resolvePromise(false);
            });

            child.on('close', () => {
                resolvePromise(true);
            });
        });
    }

    private async buildInstaller(commandOptions: IBuildCommandOptions): Promise<void> {
        console.log(`Building installer from script '${this.context.installerScript}'`);
        console.log(`Using Inno Setup binary '${commandOptions.command}'`);
        console.log(`Using working directory '${commandOptions.cwd}'`);

        await new Promise<void>((resolvePromise, rejectPromise) => {
            const startProcess = (useShell: boolean): ChildProcess => {
                return childProcess.spawn(commandOptions.command, commandOptions.args, {
                    cwd: commandOptions.cwd,
                    env: commandOptions.env,
                    shell: useShell,
                });
            };

            const fallbackCommand = `"${commandOptions.command}" ${commandOptions.args
                .map((arg) => `"${arg}"`)
                .join(' ')}`;
            let fallbackAttempted = false;
            let stderrBuffer = '';

            const launchWithListeners = (proc: ChildProcess, isFallback: boolean): void => {
                if (isFallback) {
                    stderrBuffer = '';
                }

                proc.stdout?.on('data', (data) => {
                    console.log(data.toString());
                });

                proc.stderr?.on('data', (data) => {
                    const chunk = data.toString();
                    stderrBuffer += chunk;
                    console.error(chunk);
                });

                proc.on('error', (error) => {
                    const details = (error as NodeJS.ErrnoException).code
                        ? `${(error as NodeJS.ErrnoException).code}: ${(error as Error).message}`
                        : (error as Error).message;

                    if (!fallbackAttempted && process.platform === 'win32') {
                        fallbackAttempted = true;
                        console.warn(
                            `Inno Setup spawn failed (${details}). Attempting shell fallback with command: ${fallbackCommand}`,
                        );
                        launchWithListeners(startProcess(true), true);
                        return;
                    }

                    rejectPromise(new Error(`Failed to execute Inno Setup CLI (${details}).`));
                });

                proc.on('close', (code) => {
                    if (code === 0) {
                        resolvePromise();
                        return;
                    }

                    const errorMessage = stderrBuffer.trim() || 'Inno Setup CLI exited with an unknown error.';
                    rejectPromise(new Error(`Inno Setup CLI exited with code ${code ?? 'unknown'}: ${errorMessage}`));
                });
            };

            try {
                launchWithListeners(startProcess(false), false);
            } catch (error) {
                const details = (error as NodeJS.ErrnoException).code
                    ? `${(error as NodeJS.ErrnoException).code}: ${(error as Error).message}`
                    : (error as Error).message;

                console.warn(
                    `Direct spawn of Inno Setup failed immediately (${details}). Attempting shell fallback with command: ${fallbackCommand}`,
                );

                fallbackAttempted = true;
                launchWithListeners(startProcess(true), true);
            }
        });
    }

    // ----------------------------------------------------------------- Paths

    private getRuntimePath(filePath: string, useWindowsPaths: boolean): string {
        if (!useWindowsPaths || !path.isAbsolute(filePath)) {
            // relative paths (RA1 [Setup] SourceDir) stay relative: Inno
            // resolves them against the .iss location, which wine sees fine
            return filePath;
        }

        return this.toWinePath(filePath);
    }

    private toWinePath(filePath: string): string {
        return `Z:${filePath.replace(/\//g, '\\')}`;
    }
}
