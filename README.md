# cncnet-package-tools

Shared build / packing / installer tooling for the CnCNet game client packages. This repo is
intended to be used as a **git submodule** of the game package repos (`ts`, `yr`, `ra`, `td`),
so all games share one code base, one Inno Setup tree, and one set of helpers.

All utilities are run from the tools root via `npm run <script>` (npm workspaces).

## Game profiles (`games/`)

The per-game values that used to be hard-coded per repo live in a single source of truth:

| Profile     | Game            | Status |
| ----------- | --------------- | ------ |
| `games/ts.json`  | Tiberian Sun  | onboarded |
| `games/ra1.json` | Red Alert 1   | onboarded |
| `games/yr.json`  | Yuri's Revenge | onboarded |
| `games/td.json`  | Tiberian Dawn | **stub** — a minimal profile; icon/license/output/appId are filled in when TD is onboarded |

A profile defines the app metadata, version-file location, package dir,
installer resources (icon/license), output name/dir,
`excludedFiles`, `requiredFiles` (warn-on-missing), the `[InstallDelete]` parsing
strategy, movie downloads, and the mix-packer settings (`nameFormat`, `xccGameId`,
in/out dirs, and whether mixes are built inside the installer service).

Every tool accepts `--game <id>` to resolve these values. The accepted ids are the keys
of the profiles: `ts`, `ra1`, `yr`, `td`.

## Usage

All commands run from the tools root. `--workingDir` remains available on every
tool as an explicit override that bypasses the profile's `packageDir`.

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

Output: `<profile.output.dir>/<App>_Installer.exe` (see the profile's `output.baseFilename`).

The wizard title bar shows the client version (from the package's `version` file)
plus the installer version (`installerVersion` in `build-installer/constants.ts` —
currently `0.1.0`; bump it manually when installer behavior changes), e.g.
`Setup - CnCNet Red Alert 0.0 (Installer 0.1.0)`.

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
- `--inDir <dir>` / `--outDir <dir>` — optional overrides of the profile dirs.

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

## Release utilities

These are CI-oriented and are not profile-driven:

| Script                        | Package                 | Description |
| ----------------------------- | ----------------------- | ----------- |
| `npm run release-tag-validator`   | `release-tag-validator`   | Validates that a release tag matches the `yr-x.y` / `yr-x.y.z` format (still YR-specific). |
| `npm run release-asset-uploader`  | `release-asset-uploader`  | Uploads a file as a GitHub release asset for the current tag. |
| `npm run publish-release`         | `publish-release`         | Publishes the latest version to the server and sends an IRC release notification. |
| `npm run ladder-maps-sync`        | `ladder-maps-sync`        | Synchronizes ladder maps. |

## Shared packages

| Package       | Purpose |
| ------------- | ------- |
| `cncnet-core` | Shared interfaces, constants, and services used by the utilities (GitHub API, SSH, IRC, option values, and the **game-profile service** that loads `games/*.json`). |

## Notes

- `build-installer`, `mix-packer`, `version-writer`, `map-name-case-fix`, and `mpmaps-updater`
  all require `--game` (or `--workingDir`/explicit dirs as a fallback) when run directly.
- The Inno Setup script, template, and libs under `build-installer/inno/` are shared by all games;
  the per-game differences are driven entirely by the `games/` profile at render time.
- Onboarding a new game: add a `games/<id>.json` profile, add its template/resources under
  `build-installer/inno/`, and the tools pick it up automatically.
