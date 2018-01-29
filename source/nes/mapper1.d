module nes.mapper1;

import std.base64;
import std.conv;
import std.format;
import std.stdio;

import nes.cartridge;
import nes.mapper;
import nes.memory;

class Mapper1 : Mapper {
    this(Cartridge cartridge) {
        this.cart = cartridge;
        this.shiftRegister = 0x10;
        this.prgOffsets[1] = this.prgBankOffset(-1);
    }

    void step() {
    }

    ubyte read(ushort address) {
        if (address < 0x2000) {
            auto bank = address / 0x1000;
            auto offset = address % 0x1000;
            return this.cart.chr[this.chrOffsets[bank] + cast(int)offset];
        }
        else if (address >= 0x8000) {
            address = cast(ushort)(address - 0x8000);
            auto bank = address / 0x4000;
            auto offset = address % 0x4000;
            return this.cart.prg[this.prgOffsets[bank] + cast(int)offset];
        }
        else if (address >= 0x6000) {
            return this.cart.sram[cast(int)address - 0x6000];
        }
        else {
            throw new MapperException(format("unhandled mapper1 read at address: 0x%04X", address));
        }
    }

    void write(ushort address, ubyte value) {
        if (address < 0x2000) {
            auto bank = address / 0x1000;
            auto offset = address % 0x1000;
            this.cart.chr[this.chrOffsets[bank] + cast(int)offset] = value;
        }
        else if (address >= 0x8000) {
            this.loadRegister(address, value);
        }
        else if (address >= 0x6000) {
            this.cart.sram[cast(int)address - 0x6000] = value;
        }
        else {
            throw new MapperException(format("unhandled mapper1 write at address: 0x%04X", address));
        }
    }

    void loadRegister(ushort address, ubyte value) {
        if ((value & 0x80) == 0x80) {
            this.shiftRegister = 0x10;
            this.writeControl(this.control | 0x0C);
        } else {
            auto complete = (this.shiftRegister & 1) == 1;
            this.shiftRegister >>= 1;
            this.shiftRegister |= (value & 1) << 4;
            if (complete) {
                this.writeRegister(address, this.shiftRegister);
                this.shiftRegister = 0x10;
            }
        }
    }

    void writeRegister(ushort address, ubyte value) {
        if (address <= 0x9FFF) {
            this.writeControl(value);
        }
        else if (address <= 0xBFFF) {
            this.writeCHRBank0(value);
        }
        else if (address <= 0xDFFF) {
            this.writeCHRBank1(value);
        }
        else if (address <= 0xFFFF) {
            this.writePRGBank(value);
        }
    }

    // Control (internal, $8000-$9FFF)
    void writeControl(ubyte value) {
        this.control = value;
        this.chrMode = (value >> 4) & 1;
        this.prgMode = (value >> 2) & 3;
        auto mirror = value & 3;

        switch (mirror) {
            case 0:
                this.cart.mirror = MirrorSingle0;
                break;
            case 1:
                this.cart.mirror = MirrorSingle1;
                break;
            case 2:
                this.cart.mirror = MirrorVertical;
                break;
            case 3:
                this.cart.mirror = MirrorHorizontal;
                break;
            default:
                break;
        }

        this.updateOffsets();
    }

    // CHR bank 0 (internal, $A000-$BFFF)
    void writeCHRBank0(ubyte value) {
        this.chrBank0 = value;
        this.updateOffsets();
    }

    // CHR bank 1 (internal, $C000-$DFFF)
    void writeCHRBank1(ubyte value) {
        this.chrBank1 = value;
        this.updateOffsets();
    }

    // PRG bank (internal, $E000-$FFFF)
    void writePRGBank(ubyte value) {
        this.prgBank = value & 0x0F;
        this.updateOffsets();
    }

    int prgBankOffset(int index) {
        if (index >= 0x80) {
            index -= 0x100;
        }
        index %= this.cart.prg.length / 0x4000;
        auto offset = index * 0x4000;
        if (offset < 0) {
            offset += this.cart.prg.length;
        }
        return offset;
    }

    int chrBankOffset(int index) {
        if (index >= 0x80) {
            index -= 0x100;
        }
        index %= this.cart.chr.length / 0x1000;
        auto offset = index * 0x1000;
        if (offset < 0) {
            offset += this.cart.chr.length;
        }
        return offset;
    }

    // PRG ROM bank mode (0, 1: switch 32 KB at $8000, ignoring low bit of bank number;
    //                    2: fix first bank at $8000 and switch 16 KB bank at $C000;
    //                    3: fix last bank at $C000 and switch 16 KB bank at $8000)
    // CHR ROM bank mode (0: switch 8 KB at a time; 1: switch two separate 4 KB banks)
    void updateOffsets() {
        switch (this.prgMode) {
            case 0, 1:
                this.prgOffsets[0] = this.prgBankOffset(cast(int)(this.prgBank & 0xFE));
                this.prgOffsets[1] = this.prgBankOffset(cast(int)(this.prgBank | 0x01));
                break;
            case 2:
                this.prgOffsets[0] = 0;
                this.prgOffsets[1] = this.prgBankOffset(cast(int)this.prgBank);
                break;
            case 3:
                this.prgOffsets[0] = this.prgBankOffset(cast(int)this.prgBank);
                this.prgOffsets[1] = this.prgBankOffset(-1);
                break;
            default:
                break;
        }

        switch (this.chrMode) {
            case 0:
                this.chrOffsets[0] = this.chrBankOffset(cast(int)(this.chrBank0 & 0xFE));
                this.chrOffsets[1] = this.chrBankOffset(cast(int)(this.chrBank0 | 0x01));
                break;
            case 1:
                this.chrOffsets[0] = this.chrBankOffset(cast(int)this.chrBank0);
                this.chrOffsets[1] = this.chrBankOffset(cast(int)this.chrBank1);
                break;
            default:
                break;
        }
    }

    void save(string[string] state) {
        state["mapper1.shiftRegister"] = to!string(this.shiftRegister);
        state["mapper1.control"] = to!string(this.control);
        state["mapper1.prgMode"] = to!string(this.prgMode);
        state["mapper1.chrMode"] = to!string(this.chrMode);
        state["mapper1.prgBank"] = to!string(this.prgBank);
        state["mapper1.chrBank0"] = to!string(this.chrBank0);
        state["mapper1.chrBank1"] = to!string(this.chrBank1);
        state["mapper1.prgOffsets"] = to!string(this.prgOffsets);
        state["mapper1.chrOffsets"] = to!string(this.chrOffsets);
    }

    void load(string[string] state) {
        this.shiftRegister = to!ubyte(state["mapper1.shiftRegister"]);
        this.control = to!ubyte(state["mapper1.control"]);
        this.prgMode = to!ubyte(state["mapper1.prgMode"]);
        this.chrMode = to!ubyte(state["mapper1.chrMode"]);
        this.prgBank = to!ubyte(state["mapper1.prgBank"]);
        this.chrBank0 = to!ubyte(state["mapper1.chrBank0"]);
        this.chrBank1 = to!ubyte(state["mapper1.chrBank1"]);
        this.prgOffsets = to!(int[2])(state["mapper1.prgOffsets"]);
        this.chrOffsets = to!(int[2])(state["mapper1.chrOffsets"]);
    }

    private:
        Cartridge cart;
        ubyte     shiftRegister;
        ubyte     control;
        ubyte     prgMode;
        ubyte     chrMode;
        ubyte     prgBank;
        ubyte     chrBank0;
        ubyte     chrBank1;
        int[2]    prgOffsets;
        int[2]    chrOffsets;
}
