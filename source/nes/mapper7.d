module nes.mapper7;

import std.conv;
import std.format;

import nes.cartridge;
import nes.mapper;
import nes.memory;

class Mapper7 : Mapper {
    this(Cartridge cartridge) {
        this.cart = cartridge;
        this.prgBank = 0;
    }

    void step() {
    }

    ubyte read(ushort address) {
        if (address < 0x2000) {
            return this.cart.chr[address];
        }
        else if (address >= 0x8000) {
            auto index = this.prgBank * 0x8000 + cast(int)(address - 0x8000);
            return this.cart.prg[index];
        }
        else if (address >= 0x6000) {
            auto index = cast(int)address - 0x6000;
            return this.cart.sram[index];
        }
        else {
            throw new MapperException(format("unhandled mapper7 read at address: 0x%04X", address));
        }
    }

    void write(ushort address, ubyte value) {
        if (address < 0x2000) {
            this.cart.chr[address] = value;
        }
        else if (address >= 0x8000) {
            this.prgBank = cast(int)(value & 7);
            switch (value & 0x10) {
                case 0x00:
                    this.cart.mirror = MirrorSingle0;
                    break;
                case 0x10:
                    this.cart.mirror = MirrorSingle1;
                    break;
                default:
                    break;
            }
        }
        else if (address >= 0x6000) {
            auto index = cast(int)address - 0x6000;
            this.cart.sram[index] = value;
        }
        else {
            throw new MapperException(format("unhandled mapper7 write at address: 0x%04X", address));
        }
    }

    void save(string[string] state) {
        state["mapper7.prgBank"] = to!string(this.prgBank);
    }

    void load(string[string] state) {
        this.prgBank = to!int(state["mapper7.prgBank"]);
    }

    private:
        Cartridge cart;
        int prgBank;
}
