import { parseArgs } from 'util';
import * as path from 'path';

import { loadGameProfile, resolveGamePackageDir } from 'cncnet-core/service/game-profile.service';

import ExFS from './ExFS';
import MIXFile from './MIXFile';
import type { NameFormat } from './NameFormat';

function getOptions() {
    const { values } = parseArgs({
        options: {
            game: {
                type: 'string',
                short: 'g',
            },
            inDir: {
                type: 'string',
                short: 'i',
            },
            outDir: {
                type: 'string',
                short: 'o',
            },
            xccGameId: {
                type: 'string',
                default: '5',
            },
            nameFormat: {
                type: 'string',
                default: 'padded-crc32',
            },
            'no-lmd': {
                type: 'boolean',
                default: false,
            },
        },
    });

    let inDir = values.inDir ? path.resolve(values.inDir) : undefined;
    let outDir = values.outDir ? path.resolve(values.outDir) : undefined;
    let xccGameId = parseXccGameId(values.xccGameId);
    let nameFormat = parseNameFormat(values.nameFormat);

    if (values.game) {
        // --game: mix pins (inDir/outDir/nameFormat/xccGameId) come from the
        // game profile, resolved against the package dir. Explicit
        // --inDir/--outDir still win over the profile defaults.
        const profile = loadGameProfile(values.game);
        const packageDir = resolveGamePackageDir(profile);
        inDir = inDir ?? path.resolve(packageDir, profile.mixes.inDir);
        outDir = outDir ?? path.resolve(packageDir, profile.mixes.outDir);
        xccGameId = profile.mixes.xccGameId;
        nameFormat = profile.mixes.nameFormat;
    }

    if (!inDir || !outDir) {
        console.error('Missing required arguments: --inDir and --outDir (or --game)');
        console.error('Example: npm run mix-packer -- --inDir /path/to/game-assets --outDir /path/to/package');
        console.error('Example: npm run mix-packer -- --game yr');
        process.exit(1);
    }

    return {
        inDir,
        outDir,
        xccGameId,
        nameFormat,
        includeLmd: !values['no-lmd'],
    };
}

function parseNameFormat(value: string | undefined): NameFormat {
    const format = value ?? 'padded-crc32';
    if (format !== 'rol1' && format !== 'padded-crc32' && format !== 'rol3' && format !== 'ror6') {
        console.error('Invalid --nameFormat. Use rol1, padded-crc32, rol3, or ror6.');
        process.exit(1);
    }
    return format;
}

function parseXccGameId(value: string | undefined) {
    const code = Number(value ?? '5');

    if (!Number.isInteger(code) || code < 0 || code > 0xff) {
        console.error('Invalid --xccGameId. Use an integer byte value from 0 to 255.');
        process.exit(1);
    }

    return code;
}

function main() {
    const { inDir, outDir, xccGameId, nameFormat, includeLmd } = getOptions();

    console.log(`Packing MIX files from '${inDir}' to '${outDir}'`);

    ExFS.deleteAllMix(inDir);
    const packArray = ExFS.GetPackArray(inDir);

    if (packArray.length === 0) {
        // Refuse to no-op: packing zero mixes means a wrong --inDir or a
        // MixSource that still uses the legacy '*.mix' folder names (the
        // packer only reads '*.pack'). Either way an empty result would let
        // build-installer ship an installer with no game assets.
        console.error(`No '*.pack' entries found in '${inDir}'. Aborting - nothing was packed.`);
        console.error('Expected folders like MixSource/<name>.pack.');
        process.exit(1);
    }

    for (const item of packArray) {
        const parse = path.parse(item);

        let currentOutDir = path.normalize(parse.dir);
        if (!inPack(currentOutDir, inDir)) {
            currentOutDir = outDir;
        }

        ExFS.mkdir(currentOutDir);
        const mix = path.join(currentOutDir, parse.name + '.mix');
        const pack = path.join(parse.dir, parse.base);

        console.log(mix);
        new MIXFile(pack, xccGameId, nameFormat, includeLmd).save(mix);
    }
}

function inPack(mixDir: string, inDir: string) {
    return (
        mixDir
            .replace(inDir, '')
            .split(path.sep)
            .findIndex((i) => i.endsWith('.pack')) !== -1
    );
}

main();
