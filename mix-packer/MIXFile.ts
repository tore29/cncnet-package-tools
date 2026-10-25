import * as fs from 'fs';
import * as path from 'path';

import ExBuffer from './ExBuffer';
import ExFS from './ExFS';
import { getNameIdAlgorithm, type NameFormat, type NameIdAlgorithm } from './NameFormat';

export default class MIXFile {
    folderPath: string;
    xccGameId: number;
    nameIdAlgorithm: NameIdAlgorithm;
    includeLmd: boolean;
    body: ExBuffer;

    includedFilesID: Map<
        number,
        {
            id: number;
            offset: number;
            size: number;
            fileName: string;
        }
    >;

    // CreateFromFolder
    constructor(folderPath: string, xccGameId = 5, nameFormat: NameFormat = 'padded-crc32', includeLmd = true) {
        this.folderPath = folderPath;
        this.xccGameId = xccGameId;
        this.nameIdAlgorithm = getNameIdAlgorithm(nameFormat);
        this.includeLmd = includeLmd;
        this.includedFilesID = new Map();

        const filesArray = ExFS.GetFileArray(this.folderPath);

        this.body = new ExBuffer(ExFS.GetFolderSize(this.folderPath) + filesArray.length);

        for (let i = 0; i < filesArray.length; i++) {
            this.addFile(filesArray[i]);
            // console.log(i + 1, " of ", filesArray.length, "\r");
        }
    }

    addFile(filePath: string) {
        const fileName = path.basename(filePath);
        const id = this.nameIdAlgorithm.getId(fileName);

        if (this.includedFilesID.has(id)) {
            console.log(`fileID =${id.toString(16)}, filePath =${filePath} Has in ${path}`);
            throw new Error();
        }

        const fileBuffer = ExFS.GetFile(filePath);
        const offset = this.body.findOrCopy(fileBuffer);
        const size = fileBuffer.length;

        this.includedFilesID.set(id, { id, offset, size, fileName });

        return this;
    }

    addLocalMixDatabase() {
        const fileName = 'local mix database.dat';

        // Lowercase the names: the XCC database convention is lowercase
        // filenames, and the legacy packers normalized this way too
        // (e.g. BuildMixes.ps1 ToLowerInvariant). Member IDs are already
        // case-insensitive, so this only affects the name list itself.
        const fileList = Array.from(this.includedFilesID.values()).map((el) => el.fileName.toLowerCase());
        fileList.push(fileName);
        fileList.sort();

        const body = fileList.join('\x00');
        const size = 0x34 + body.length + 1;

        const fileBuffer = Buffer.alloc(size, 0);
        fileBuffer.write('XCC by Olaf van der Spek', 0);
        fileBuffer.writeInt32BE(0x1a041727, 0x18);
        fileBuffer.writeInt32BE(0x10198000, 0x1c);

        fileBuffer.writeInt32LE(size, 0x20);

        fileBuffer.writeUInt8(this.xccGameId, 0x2c);
        fileBuffer.writeInt32LE(fileList.length, 0x30);
        fileBuffer.write(body, 0x34);

        const id = this.nameIdAlgorithm.getId(fileName);
        const offset = this.body.findOrCopy(fileBuffer);
        this.includedFilesID.set(id, { id, offset, size, fileName });

        return this;
    }

    getHeader() {
        const array = Array.from(this.includedFilesID.values());
        array.sort((a, b) => ~~a.id - ~~b.id);

        // Basic Classic layout:
        //   uint16 entry count
        //   uint32 data block size
        //   count * { uint32 id, uint32 offset, uint32 size }
        // Offsets are relative to the beginning of the data block.
        const buf = new ExBuffer(array.length * 12 + 6);
        buf.offset = 6;

        for (const item of array) {
            buf.write(item.id);
            buf.write(item.offset);
            buf.write(item.size);
        }

        const result = buf.GetBuffer();
        result.writeUInt16LE(array.length, 0);
        result.writeUInt32LE(this.body.offset, 2);

        return result;
    }

    getBody() {
        return this.body.GetBuffer();
    }

    save(mixPath: string): this {
        if (this.includeLmd) {
            this.addLocalMixDatabase();
        } else if (this.includedFilesID.size === 0) {
            const fileName = 'local mix database.dat';
            const id = this.nameIdAlgorithm.getId(fileName);
            const offset = this.body.findOrCopy(Buffer.alloc(0));
            this.includedFilesID.set(id, { id, offset, size: 0, fileName });
        }
        const headerBuffer = this.getHeader();
        const bodyBuffer = this.getBody();

        fs.writeFileSync(mixPath, headerBuffer);
        fs.appendFileSync(mixPath, bodyBuffer);
        return this;
    }

    // ===== statics =====
}
