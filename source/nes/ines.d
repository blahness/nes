module nes.ines;

import std.stdio;

import nes.cartridge;

enum iNESFileMagic = 0x1a53454e;

align(1) struct iNESFileHeader {
    uint     magic;    // iNES magic number
    ubyte    numPRG;   // number of PRG-ROM banks (16KB each)
    ubyte    numCHR;   // number of CHR-ROM banks (8KB each)
    ubyte    control1; // control bits
    ubyte    control2; // control bits
    ubyte    numRAM;   // PRG-RAM size (x 8KB)
    ubyte[7] padding;  // unused padding
}

class NesFileException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

// LoadNESFile reads an iNES file (.nes) and returns a Cartridge on success.
// http://wiki.nesdev.com/w/index.php/INES
// http://nesdev.com/NESDoc.pdf (page 28)
Cartridge LoadNESFile(string path) {
    // open file
    auto file = File(path);

    // read file header
    iNESFileHeader[1] headers;
    file.rawRead(headers);

    // verify header magic number
    if (headers[0].magic != iNESFileMagic) {
        throw new NesFileException("invalid .nes file");
    }

    // mapper type
    auto mapper1 = cast(ubyte)(headers[0].control1 >> 4);
    auto mapper2 = cast(ubyte)(headers[0].control2 >> 4);
    auto mapper = cast(ubyte)(mapper1 | mapper2 << 4);

    // mirroring type
    auto mirror1 = cast(ubyte)(headers[0].control1 & 1);
    auto mirror2 = cast(ubyte)((headers[0].control1 >> 3) & 1);
    auto mirror = cast(ubyte)(mirror1 | mirror2 << 1);

    // battery-backed RAM
    auto battery = cast(ubyte)((headers[0].control1 >> 1) & 1);

    // read trainer if present (unused)
    if ((headers[0].control1 & 4) == 4) {
        auto trainer = new ubyte[512];
        file.rawRead(trainer);
    }

    // read prg-rom bank(s)
    auto prg = new ubyte[cast(int)headers[0].numPRG * 16384];
    file.rawRead(prg);

    // read chr-rom bank(s)
    bool chrRAM;
    ubyte[] chr;

    if (headers[0].numCHR > 0) {
        chr = new ubyte[cast(int)headers[0].numCHR * 8192];
        file.rawRead(chr);
    } else {
        // provide chr-ram if not in file
        chr = new ubyte[8192];
        chrRAM = true;
    }

    // success
    return new Cartridge(prg, chr, mapper, mirror, battery, chrRAM);
}
