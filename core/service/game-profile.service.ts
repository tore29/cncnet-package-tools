import * as fs from 'fs';
import * as path from 'path';
import * as url from 'url';

import { type GameId, type IGameProfile } from 'cncnet-core/interface/game-profile.interface';

const currentDir = path.dirname(url.fileURLToPath(import.meta.url));
const toolsRootPath = path.resolve(currentDir, '../..');
const gamesDirPath = path.resolve(toolsRootPath, 'games');

const knownGameIds: GameId[] = ['td', 'ra1', 'ts', 'yr'];

/**
 * The root of the tools repo (this package lives in <tools-root>/core).
 */
export function getToolsRootPath(): string {
    return toolsRootPath;
}

/**
 * Load and validate a game profile from `games/<id>.json`.
 * Exits the process with a clear error when the game is unknown or the
 * profile is missing/invalid (CLI context).
 */
export function loadGameProfile(gameId: string): IGameProfile {
    if (knownGameIds.indexOf(gameId as GameId) === -1) {
        console.error(`Unknown game '${gameId}'. Available games: ${knownGameIds.join(', ')}`);
        process.exit(1);
    }

    const profilePath = path.resolve(gamesDirPath, `${gameId}.json`);
    let profile: IGameProfile;

    try {
        profile = JSON.parse(fs.readFileSync(profilePath, 'utf-8')) as IGameProfile;
    } catch (error) {
        console.error(`Failed to load game profile '${profilePath}': ${(error as Error).message}`);
        process.exit(1);
    }

    if (profile.id !== gameId) {
        console.error(`Game profile '${profilePath}' has id '${profile.id}', expected '${gameId}'.`);
        process.exit(1);
    }

    return profile;
}

/**
 * Resolve the client package dir for a profile: an explicit --workingDir
 * override wins, otherwise the profile's packageDir (relative to the tools
 * repo root).
 */
export function resolveGamePackageDir(profile: IGameProfile, workingDirOverride?: string): string {
    if (workingDirOverride) {
        return path.resolve(workingDirOverride);
    }

    return path.resolve(toolsRootPath, profile.packageDir);
}
