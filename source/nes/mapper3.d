module nes.mapper3;

import std.conv;
import std.format;

import nes.cartridge;
import nes.mapper;

class Mapper3 : Mapper {
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
            throw new MapperException(format("unhandled mapper3 read at address: 0x%04X", address));
        }
    }

    void write(ushort address, ubyte value) {
        if (address < 0x2000) {
            auto index = this.chrBank * 0x2000 + cast(int)address;
            this.cart.chr[index] = value;
        }
        else if (address >= 0x8000) {
            this.chrBank = cast(int)(value & 3);
        }
        else if (address >= 0x6000) {
            auto index = cast(int)address - 0x6000;
            this.cart.sram[index] = value;
        }
        else {
            throw new MapperException(format("unhandled mapper3 write at address: 0x%04X", address));
        }
    }

    void save(string[string] state) {
        state["mapper3.chrBank"] = to!string(this.chrBank);
        state["mapper3.prgBank1"] = to!string(this.prgBank1);
        state["mapper3.prgBank2"] = to!string(this.prgBank2);
    }

    void load(string[string] state) {
        this.chrBank = to!int(state["mapper3.chrBank"]);
        this.prgBank1 = to!int(state["mapper3.prgBank1"]);
        this.prgBank2 = to!int(state["mapper3.prgBank2"]);
    }

    private:
        Cartridge cart;
        int chrBank;
        int prgBank1;
        int prgBank2;
}
