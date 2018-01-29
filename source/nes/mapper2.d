module nes.mapper2;

import std.conv;
import std.format;

import nes.cartridge;
import nes.mapper;

class Mapper2 : Mapper {
    this(Cartridge cartridge) {
        this.cart = cartridge;
        this.prgBanks = cast(int)(cartridge.prg.length / 0x4000);
        this.prgBank1 = 0;
        this.prgBank2 = this.prgBanks - 1;
    }

    void step() {
    }

    ubyte read(ushort address) {
        if (address < 0x2000) {
            return this.cart.chr[address];
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
            throw new MapperException(format("unhandled mapper2 read at address: 0x%04X", address));
        }
    }

    void write(ushort address, ubyte value) {
        if (address < 0x2000) {
            this.cart.chr[address] = value;
        }
        else if (address >= 0x8000) {
            this.prgBank1 = cast(int)value % this.prgBanks;
        }
        else if (address >= 0x6000) {
            auto index = cast(int)address - 0x6000;
            this.cart.sram[index] = value;
        }
        else {
            throw new MapperException(format("unhandled mapper2 write at address: 0x%04X", address));
        }
    }

    void save(string[string] state) {
        state["mapper2.prgBanks"] = to!string(this.prgBanks);
        state["mapper2.prgBank1"] = to!string(this.prgBank1);
        state["mapper2.prgBank2"] = to!string(this.prgBank2);
    }

    void load(string[string] state) {
        this.prgBanks = to!int(state["mapper2.prgBanks"]);
        this.prgBank1 = to!int(state["mapper2.prgBank1"]);
        this.prgBank2 = to!int(state["mapper2.prgBank2"]);
    }

    private:
        Cartridge cart;
        int prgBanks;
        int prgBank1;
        int prgBank2;
}
