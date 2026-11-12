# cncnet-package-tools

Shared build / packing / installer tooling for the CnCNet game client packages. This repo is
intended to be used as a **git submodule** of the game package repos (`ts`, `yr`, `ra`, `td`),
so all games share one code base, one Inno Setup tree, and one set of helpers.

All utilities are run from the tools root via `npm run <script>` (npm workspaces).

## Game profiles (`games/`)

The per-game values live in a single source of truth:

| Profile          | Game           | Status |
| ---------------- | -------------- | ------ |
| `games/ts.json`  | Tiberian Sun   | onboarded |
| `games/ra1.json` | Red Alert 1    | onboarded |
| `games/yr.json`  | Yuri's Revenge | onboarded |
| `games/td.json`  | Tiberian Dawn  | **stub** — a minimal profile; license, output name, and appId are filled in when TD is onboarded |

A profile defines the app metadata, the version-file location, the package kind
(`patch` or `standalone`), the package dir, the installer resources (icon/license), the
output name/dir, `excludedFiles`, `requiredFiles` (missing files fail the build), the
`[InstallDelete]` parsing strategy, the movie download lists, and the mix-packer settings
(`nameFormat`, `xccGameId`, in/out dirs, and whether mixes are built inside the installer
service).

The profile-driven tools accept `--game <id>` to resolve these values. The accepted ids are
the profile keys: `ts`, `ra1`, `yr`, `td`.

## Utilities

| Script                      | Package             | Short Description |
| --------------------------- | ------------------- | ----------------- |
| `npm run build-installer`   | `build-installer`   | Renders the Inno Setup template for the game and builds the installer from the package contents; on Linux it runs `ISCC.exe` via `wine`. |
| `npm run csf-converter`     | `csf-converter`     | Converts the committed `.csf.ini` source files into the binary `.csf` files expected by the game. See `csf-converter/README.md`. |
| `npm run map-name-case-fix` | `map-name-case-fix` | Fixes the filename casing of map preview `.png` files based on keys from `MPMaps.ini`. |
| `npm run mix-packer`        | `mix-packer`        | Packs `.pack` directories into `.mix` archives; the source/output dirs come from the profile's `mixes` settings or from `--inDir`/`--outDir`. |
| `npm run mpmaps-updater`    | `mpmaps-updater`    | Synchronizes `INI/MPMaps.ini` with the maps in the package: adds new maps, updates existing ones, and removes missing ones. |
| `npm run version-writer`    | `version-writer`    | Writes version data for the package contents with the vendored `VersionWriter.exe`; on Linux it runs via `mono` or `wine`. |

The CI-oriented release utilities are listed under [Release utilities](#release-utilities).

## Usage

All commands run from the tools root. For the profile-driven tools, `--game <id>` selects
the profile and `--workingDir` optionally overrides the profile's `packageDir`.
`csf-converter` is not profile-driven and scans fixed directories instead (see its section).

### build-installer

Renders the Inno Setup template for the chosen game, verifies required files, and
compiles the installer with `ISCC.exe` (via `wine` on Linux).

```
npm run build-installer -- --game yr
npm run build-installer -- --game ra1
npm run build-installer -- --game ts
```

Options:

- `--game <id>` — required. Selects the profile (template, resources, output, …).
- `--workingDir <dir>` — optional override of the profile's package dir.

Output: `<profile.output.dir>/<output.baseFilename>.exe` (e.g. `installer-output/CnCNet5_TS_Installer.exe`).

The wizard title bar shows the client version (from the package's `version` file)
plus the installer version (`installerVersion` in `build-installer/constants.ts` —
currently `0.1.0`; bump it manually when installer behavior changes), e.g.
`Setup - CnCNet Red Alert 0.1.2 (Installer 0.1.0)`.

ISCC resolution order: `INNO_SETUP_ISCC`/`ISCC_PATH` env → vendored `inno/bin/ISCC.exe`
→ well-known Inno 7/6 install locations → `where ISCC.exe`. On Linux, `wine` is used
with a local prefix under `build-installer/.wine`.

### mix-packer

Packs `.pack` mix-source directories into `.mix` archives. The source/output dirs
come from the profile's `mixes.inDir`/`outDir` (TS: `MixSource` → `MIX`; YR/RA1:
`../game-assets` → `.`).

```
npm run mix-packer -- --game yr
npm run mix-packer -- --game ts --inDir <dir> --outDir <dir>
```

Options:

- `--game <id>` — resolves `mixes.inDir`/`outDir`, `nameFormat`, and `xccGameId` from the profile.
- `--inDir <dir>` / `--outDir <dir>` — source/output dirs; required when `--game` is not given, otherwise they override the profile dirs.
- `--xccGameId <0-255>` — XCC Game ID for the embedded local database (default `5`; with `--game`, the profile value wins).
- `--nameFormat <format>` — `rol1`, `padded-crc32`, `rol3`, or `ror6` (default `padded-crc32`; with `--game`, the profile value wins).
- `--no-lmd` — omit `local mix database.dat` from the generated MIX files.

See `mix-packer/README.md` for the full option reference.

### version-writer

Writes the version file for the package contents (wraps `VersionWriter.exe`; via
`mono`/`wine` on Linux).

```
npm run version-writer -- --game yr
```

Options:

- `--game <id>` — resolves the working dir from the profile's `packageDir`.
- `--workingDir <dir>` — optional override.

### map-name-case-fix

Fixes the filename casing of map preview `.png` files based on keys from `MPMaps.ini`.

```
npm run map-name-case-fix -- --game yr
```

Options:

- `--game <id>` — resolves the working dir from the profile's `packageDir`.
- `--workingDir <dir>` — optional override.

### mpmaps-updater

Synchronizes `INI/MPMaps.ini` with the maps present in the package.

```
npm run mpmaps-updater -- --game yr
```

Options:

- `--game <id>` — resolves the working dir from the profile's `packageDir`.
- `--workingDir <dir>` — optional override.

### csf-converter

Converts the committed `.csf.ini` source files into the binary `.csf` files the game
reads, using the vendored `Ra2CsfFileCLI` (requires the .NET 8 runtime).

```
npm run csf-converter
npm run csf-converter -- --searchDir <dir>
```

By default it scans the package repository's `game-assets/` and `package/Resources/Translations/`.
See `csf-converter/README.md` for setup and the reverse conversion.

## Release utilities

These are CI-oriented, are not profile-driven, and expect the GitHub, SSH, and IRC
parameters of their environment:

| Script                         | Package                  | Description |
| ------------------------------ | ------------------------ | ----------- |
| `npm run release-tag-validator`  | `release-tag-validator`  | Validates that a release tag matches the `yr-x.y` / `yr-x.y.z` format (YR-specific). |
| `npm run release-asset-uploader` | `release-asset-uploader` | Uploads a file as a GitHub release asset for the current tag. |
| `npm run publish-release`        | `publish-release`        | Publishes the latest version to the server and sends an IRC release notification. |
| `npm run ladder-maps-sync`       | `ladder-maps-sync`       | Synchronizes ladder maps from the CnCNet API into the client package (`--ladder <name>`, `--dry-run`). |

## Shared packages

| Package       | Purpose |
| ------------- | ------- |
| `cncnet-core` | Shared interfaces, constants, and services used by the utilities (GitHub API, SSH, IRC, option values, and the **game-profile service** that loads `games/*.json`). |

## Notes

- `csf-converter` requires the .NET 8 runtime; `Ra2CsfFileCLI` is vendored in `csf-converter/Ra2CsfFileCLI`.
- `mix-packer` ignores `.csf.ini` sources. Run `csf-converter` before packing so the generated `.csf` files are included.
- `build-installer` requires `--game`; the other profile-driven tools require `--game` or explicit dirs (`--workingDir` for `version-writer`, `map-name-case-fix`, `mpmaps-updater`; `--inDir`/`--outDir` for `mix-packer`).
- The Inno Setup binaries (`inno/bin/`) and the shared `.iss` libs (`CncnetCommon`, `InnoDependencyInstaller`, `ISTheme`) are shared by all games; each game has its own template under `inno/templates/<id>/` and resources under `inno/Resources/`, and the rendered `inno/installer.iss` is overwritten on every build.
- Onboarding a new game: add a `games/<id>.json` profile, add its template/resources under `build-installer/inno/`, and register the id in `cncnet-core` (the `GameId` union and `knownGameIds`).
