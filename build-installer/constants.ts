import * as path from 'path';
import * as url from 'url';

import { type IGameProfile } from 'cncnet-core/interface/game-profile.interface';

/**
 * Installer version (wizard / build system) - separate from the client
 * version the installer ships. Shown in the wizard title bar next to the
 * client version (e.g. "Setup - CnCNet Red Alert 0.0 (Installer 0.1.0)").
 * Bump manually when installer behavior changes.
 */
export const installerVersion = '0.1.0';

export interface IBuildInstallerContext {
    buildInstallerPath: string;
    innoPath: string;
    innoBinPath: string;
    innoResourcesPath: string;
    installerBinary: string;
    installerTemplate: string;
    installerScript: string;
    winePrefixPath: string;
    packagePath: string;
    outputDir: string;
    setupIconPath: string;
    licenseFilePath: string;
    versionFilePath: string;
    preUpdateExecFilePath: string;
    updateExecFilePath: string;
}

/**
 * Build the absolute path context for a profile-driven installer build.
 * All shared assets (bin, libs, Resources, templates) live under
 * `build-installer/inno/`; per-game data comes from the profile.
 */
export function createContext(profile: IGameProfile, workingDir: string): IBuildInstallerContext {
    // this file lives in build-installer/
    const buildInstallerPath = path.dirname(url.fileURLToPath(import.meta.url));
    const innoPath = path.resolve(buildInstallerPath, 'inno');
    const innoBinPath = path.resolve(innoPath, 'bin');
    const innoResourcesPath = path.resolve(innoPath, 'Resources');
    const packagePath = path.resolve(workingDir);

    if (!profile.resources.icon || !profile.resources.license || !profile.output.baseFilename) {
        throw new Error(
            `Game profile '${profile.id}' is not complete enough for build-installer yet ` +
                `(missing icon, license, or output base filename - see games/${profile.id}.json).`,
        );
    }

    return {
        buildInstallerPath,
        innoPath,
        innoBinPath,
        innoResourcesPath,
        installerBinary: path.resolve(innoBinPath, 'ISCC.exe'),
        installerTemplate: path.resolve(innoPath, 'templates', profile.id, 'installer.template.iss'),
        installerScript: path.resolve(innoPath, 'installer.iss'),
        winePrefixPath: path.resolve(buildInstallerPath, '.wine'),
        packagePath,
        outputDir: path.resolve(packagePath, profile.output.dir),
        setupIconPath: path.resolve(innoResourcesPath, profile.resources.icon),
        licenseFilePath: path.resolve(innoResourcesPath, profile.resources.license),
        versionFilePath: path.resolve(packagePath, profile.version.file),
        preUpdateExecFilePath: path.resolve(packagePath, 'preupdateexec'),
        updateExecFilePath: path.resolve(packagePath, 'updateexec'),
    };
}
