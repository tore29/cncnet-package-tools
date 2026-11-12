export class TemplateAppModel {
    name!: string;
    version!: string;
    versionName!: string;
    description?: string;
    publisher!: string;
    publisherUrl!: string;
    supportUrl!: string;
    updatesUrl!: string;
    /** Inno AppId GUID (rendered into [Setup] by all templates) */
    appId?: string;
}
