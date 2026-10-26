export type GameId = 'td' | 'ra1' | 'ts' | 'yr';

export type NameFormat = 'rol1' | 'padded-crc32' | 'rol3' | 'ror6';

export type PackageKind = 'patch' | 'standalone';

/**
 * A per-game profile (`games/<id>.json`). Single source of truth for the
 * game-specific data that the shared tooling (build-installer, mix-packer,
 * version-writer, ...) needs.
 */
export interface IGameProfile {
    id: GameId;

    app: {
        /** Display name, e.g. "CnCNet Yuri's Revenge" */
        name: string;
        /** Inno AppId GUID - MUST stay stable per game (in-place upgrades) */
        appId?: string;
        /** VersionInfoDescription */
        description?: string;
        publisher: string;
        publisherUrl: string;
        supportUrl: string;
        updatesUrl: string;
    };

    version: {
        /** Version file name inside the package dir */
        file: string;
        /** INI section holding the version; null = first section of the file */
        section: string | null;
        /** INI key holding the version */
        key: string;
        /**
         * What to do when the section/key is missing:
         * - 'throw' fail the build (RA1, TS)
         * - 'undefined' render the literal string 'undefined' (YR)
         */
        missing: 'throw' | 'undefined';
        /** trim the value (RA1 trims, YR/TS do not) */
        trim?: boolean;
    };

    /** patch (RA2/YR: installs INTO the user's game folder) | standalone (freeware client) */
    packageKind: PackageKind;

    /**
     * The client package dir, relative to the tools repo root.
     * In the submodule layout (tools repo checked out at `<game-repo>/tools`)
     * this is `../package` for YR/RA1 and `..` for TS (package = repo root).
     */
    packageDir: string;

    resources: {
        /** Icon file name under build-installer/inno/Resources/ */
        icon: string | null;
        /** License file name under build-installer/inno/Resources/ */
        license: string | null;
    };

    output: {
        /** Installer exe base name, e.g. "CnCNet5_YR_Installer" */
        baseFilename: string | null;
        /** Output dir, relative to the package dir */
        dir: string;
    };

    /** Files that must NOT be shipped into the installed app (Inno [Files] Excludes) */
    excludedFiles: string[];

    requiredFiles: {
        /** Files that must exist in the package dir (relative to the package dir) */
        package: string[];
        /** Files that must exist in build-installer/inno/ (relative to the inno dir) */
        inno: string[];
    };

    /**
     * How preupdateexec/updateexec [InstallDelete] entries are extracted.
     * Per-game semantics:
     * - YR: js-ini, 2 sections, sentinel, no dedupe, sorted, filterExisting = noop-warn
     * - RA1: js-ini, 2 sections, sentinel, dedupe, sorted, filterExisting = keep-missing
     * - TS: manual line parser, 4 sections, no sentinel, dedupe, not sorted, no filter
     */
    installDelete: {
        parser: 'js-ini' | 'manual';
        sections: string[];
        /** sentinel value to drop (e.g. 'do_not_remove_this_line'); null = none */
        sentinel: string | null;
        dedupe: boolean;
        sort: boolean;
        /**
         * - 'none' keep everything (TS)
         * - 'noop-warn' YR shape: the filter is a no-op, but the per-entry
         *   existence check still runs (fire-and-forget) and warns on existing files
         * - 'keep-missing' RA1 shape: keep only entries missing from the package,
         *   warn on entries that still exist
         */
        filterExisting: 'none' | 'noop-warn' | 'keep-missing';
    };

    /**
     * Movie download list (profile-driven; the TS and RA1 templates render
     * it into the [Files] section and the download queue). Sizes in KB
     * (Inno ExternalSize / download-progress metadata).
     */
    movies?: Array<{
        file: string;
        url: string;
        sizeKB: number;
    }>;

    /** Restored-movies archive downloaded when an existing install is reused (TS). */
    extraMovies?: {
        file: string;
        url: string;
        sizeKB: number;
    };

    /**
     * mix-packer pins (authoritative, from XCC + engine sources).
     * inDir/outDir are relative to the package dir.
     */
    mixes: {
        inDir: string;
        outDir: string;
        nameFormat: NameFormat;
        xccGameId: number;
        /**
         * When true, build-installer runs the game's BuildMixes.ps1 one-shot
         * (TS hook) if the mix output dir is empty. CI runs mix-packer
         * separately (preferred); default false.
         */
        buildInService: boolean;
    };

}
