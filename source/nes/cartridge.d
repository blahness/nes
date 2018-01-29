module nes.cartridge;

import std.base64;
import std.conv;
import std.stdio;

class Cartridge {
    ubyte[] prg;   // PRG-ROM banks
    ubyte[] chr;   // CHR-ROM/RAM banks
    ubyte[] sram;  // Save RAM
    ubyte mapper;  // mapper type
    ubyte mirror;  // mirroring mode
    ubyte battery; // battery present
    bool chrIsRam;   // CHR-RAM present

    this(ubyte[] prg, ubyte[]chr, ubyte mapper, ubyte mirror, ubyte battery, bool chrIsRam) {
        this.prg = prg;
        this.chr = chr;
        this.sram = new ubyte[0x2000];
        this.mapper = mapper;
        this.mirror = mirror;
        this.battery = battery;
        this.chrIsRam = chrIsRam;
    }

    void save(string[string] state) {
        state["cartridge.sram"] = Base64.encode(this.sram);
        state["cartridge.mirror"] = to!string(this.mirror);

        if (this.chrIsRam)
            state["cartridge.chr"] = Base64.encode(this.chr);
    }

    void load(string[string] state) {
        this.sram = Base64.decode(state["cartridge.sram"]);
        this.mirror = to!ubyte(state["cartridge.mirror"]);

        if (this.chrIsRam)
            this.chr = Base64.decode(state["cartridge.chr"]);
    }
}
