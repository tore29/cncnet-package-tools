import { TemplateAppModel } from './template-app-model.class';

/** Movie / archive download metadata (profile-driven). */
export interface ITemplateMovie {
    file: string;
    url: string;
    /** File size in KB (Inno Setup ExternalSize, for the download progress bar) */
    sizeKB: number;
}

export class TemplateModel {
    app!: TemplateAppModel;

    /**
     * [Setup] SourceDir (YR) or the [Files] source path
     * (`Source: "{{ sourceDir }}\*"`, TS/RA1). Always an absolute path.
     */
    sourceDir!: string;
    outputDir!: string;
    setupIconFile!: string;
    licenseFile!: string;
    outputBaseFilename!: string;
    /**
     * Wizard title bar, pre-formatted and Pascal-escaped (app names may carry
     * apostrophes, e.g. YR): client version (package) + installer version
     * (build tool), e.g. "Setup - CnCNet Red Alert 0.0 (Installer 0.1.0)".
     */
    wizardCaption!: string;
    installDeleteFiles!: string[];

    /**
     * Always an array: the templates render it with `| join(',')` (Inno's
     * Excludes list is comma-separated, and twig would render the array
     * without spaces).
     */
    excludedInstallerFiles!: string[];

    /** [Setup] SourceDir for templates that install the package via `Source: "{{ sourceDir }}\*"`. */
    innoPath?: string;

    /** Movie download list (profile: movies). */
    movies?: ITemplateMovie[];

    /** Restored-movies archive (profile: extraMovies). */
    extraMovies?: ITemplateMovie;
}
