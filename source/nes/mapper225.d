module nes.mapper225;

import std.conv;
import std.format;
import std.stdio;

import nes.cartridge;
import nes.mapper;
import nes.memory;

class Mapper225 : Mapper {
    this(Cartridge cartridge) {
        this.cart = cartridge;
        this.chrBank = 0;
        this.prgBank1 = 0;

        auto prgBanks = cast(int)(cartridge.prg.length / 0x4000);

        this.prgBank2 = prgBanks - 1;
    }

    void step() {
    }

    ubyte read(ushort address) {
        if (address < 0x2000) {
            auto index = this.chrBank * 0x2000 + cast(int)address;
            return this.cart.chr[index];
        }
        else if (address >= 0xC000) {
            auto index = this.prgBank2 * 0x4000 + cast(int)(address - 0xC000);
            return this.cart.prg[index];
        }
        else if (address >= 0x8000) {
            auto index = this.prgBank1 * 0x4000 + cast(int)(address - 0x8000);
            return this.cart.prg[index];
        }
        else if (address >= 0x6000) {
            auto index = cast(int)address - 0x6000;
            return this.cart.sram[index];
        }
        else {
            throw new MapperException(format("unhandled mapper225 read at address: 0x%04X", address));
        }
    }

    void write(ushort address, ubyte value) {
        if (address < 0x8000) {
            return;
        }

        auto a = cast(int)address;
        auto bank = (a >> 14) & 1;
        this.chrBank = (a & 0x3f) | (bank << 6);
        auto prg = ((a >> 6) & 0x3f) | (bank << 6);
        auto mode = (a >> 12) & 1;
        if (mode == 1) {
            this.prgBank1 = prg;
            this.prgBank2 = prg;
        } else {
            this.prgBank1 = prg;
            this.prgBank2 = prg + 1;
        }

        auto mirr = (a >> 13) & 1;
        if (mirr == 1) {
            this.cart.mirror = MirrorHorizontal;
        } else {
            this.cart.mirror = MirrorVertical;
        }
    }

    void save(string[string] state) {
        state["mapper225.chrBank"] = to!string(this.chrBank);
        state["mapper225.prgBank1"] = to!string(this.prgBank1);
        state["mapper225.prgBank2"] = to!string(this.prgBank2);
    }

    void load(string[string] state) {
        this.chrBank = to!int(state["mapper225.chrBank"]);
        this.prgBank1 = to!int(state["mapper225.prgBank1"]);
        this.prgBank2 = to!int(state["mapper225.prgBank2"]);
    }

    private:
        Cartridge cart;
        int chrBank;
        int prgBank1;
        int prgBank2;
}
