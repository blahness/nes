module nes.mapper4;

import std.conv;
import std.format;

import nes.cartridge;
import nes.console;
import nes.cpu;
import nes.mapper;
import nes.memory;

class Mapper4 : Mapper {
    this(Console console, Cartridge cartridge) {
        this.console = console;
        this.cart = cartridge;

        this.prgOffsets[0] = this.prgBankOffset(0);
        this.prgOffsets[1] = this.prgBankOffset(1);
        this.prgOffsets[2] = this.prgBankOffset(-2);
        this.prgOffsets[3] = this.prgBankOffset(-1);
    }

    void step() {
        auto ppu = this.console.ppu;
        if (ppu.cycle != 280) { // TODO: this *should* be 260
            return;
        }
        if (ppu.scanLine > 239 && ppu.scanLine < 261) {
            return;
        }
        if (ppu.flagShowBackground == 0 && ppu.flagShowSprites == 0) {
            return;
        }
        this.handleScanLine();
    }

    void handleScanLine() {
        if (this.counter == 0) {
            this.counter = this.reload;
        } else {
            this.counter--;
            if (this.counter == 0 && this.irqEnable) {
                this.console.cpu.addIrqSource(IrqSource.External);
            }
        }
    }

    ubyte read(ushort address) {
        if (address < 0x2000) {
            auto bank = address / 0x0400;
            auto offset = address % 0x0400;
            return this.cart.chr[this.chrOffsets[bank] + cast(int)offset];
        }
        else if (address >= 0x8000) {
            address = cast(ushort)(address - 0x8000);
            auto bank = address / 0x2000;
            auto offset = address % 0x2000;
            return this.cart.prg[this.prgOffsets[bank] + cast(int)offset];
        }
        else if (address >= 0x6000) {
            auto index = cast(int)address - 0x6000;
            return this.cart.sram[index];
        }
        else {
            throw new MapperException(format("unhandled mapper4 read at address: 0x%04X", address));
        }
    }

    void write(ushort address, ubyte value) {
        if (address < 0x2000) {
            auto bank = address / 0x0400;
            auto offset = address % 0x0400;
            this.cart.chr[this.chrOffsets[bank] + cast(int)offset] = value;
        }
        else if (address >= 0x8000) {
            this.writeRegister(address, value);
        }
        else if (address >= 0x6000) {
            auto index = cast(int)address - 0x6000;
            this.cart.sram[index] = value;
        }
        else {
            throw new MapperException(format("unhandled mapper4 write at address: 0x%04X", address));
        }
    }

    void save(string[string] state) {
        state["mapper4.register"] = to!string(this.register);
        state["mapper4.registers"] = to!string(this.registers);
        state["mapper4.prgMode"] = to!string(this.prgMode);
        state["mapper4.chrMode"] = to!string(this.chrMode);
        state["mapper4.prgOffsets"] = to!string(this.prgOffsets);
        state["mapper4.chrOffsets"] = to!string(this.chrOffsets);
        state["mapper4.reload"] = to!string(this.reload);
        state["mapper4.counter"] = to!string(this.counter);
        state["mapper4.irqEnable"] = to!string(this.irqEnable);
    }

    void load(string[string] state) {
        this.register = to!ubyte(state["mapper4.register"]);
        this.registers = to!(ubyte[8])(state["mapper4.registers"]);
        this.prgMode = to!ubyte(state["mapper4.prgMode"]);
        this.chrMode = to!ubyte(state["mapper4.chrMode"]);
        this.prgOffsets = to!(int[4])(state["mapper4.prgOffsets"]);
        this.chrOffsets = to!(int[8])(state["mapper4.chrOffsets"]);
        this.reload = to!ubyte(state["mapper4.reload"]);
        this.counter = to!ubyte(state["mapper4.counter"]);
        this.irqEnable = to!bool(state["mapper4.irqEnable"]);
    }

    private:
        Cartridge cart;
        Console   console;
        ubyte     register;
        ubyte[8]  registers;
        ubyte     prgMode;
        ubyte     chrMode;
        int[4]    prgOffsets;
        int[8]    chrOffsets;
        ubyte     reload;
        ubyte     counter;
        bool      irqEnable;

        void writeRegister(ushort address, ubyte value) {
            if (address <= 0x9FFF && (address % 2) == 0)
                this.writeBankSelect(value);
            else if (address <= 0x9FFF && (address % 2) == 1)
                this.writeBankData(value);
            else if (address <= 0xBFFF && (address % 2) == 0)
                this.writeMirror(value);
            else if (address <= 0xBFFF && (address % 2) == 1)
                this.writeProtect(value);
            else if (address <= 0xDFFF && (address % 2) == 0)
                this.writeIRQLatch(value);
            else if (address <= 0xDFFF && (address % 2) == 1)
                this.writeIRQReload(value);
            else if (address <= 0xFFFF && (address % 2) == 0)
                this.writeIRQDisable(value);
            else if (address <= 0xFFFF && (address % 2) == 1)
                this.writeIRQEnable(value);
        }

        void writeBankSelect(ubyte value) {
            this.prgMode = (value >> 6) & 1;
            this.chrMode = (value >> 7) & 1;
            this.register = value & 7;
            this.updateOffsets();
        }

        void writeBankData(ubyte value) {
            this.registers[this.register] = value;
            this.updateOffsets();
        }

        void writeMirror(ubyte value) {
            switch (value & 1) {
                case 0:
                    this.cart.mirror = MirrorVertical;
                    break;
                case 1:
                    this.cart.mirror = MirrorHorizontal;
                    break;
                default:
                    break;
            }
        }

        void writeProtect(ubyte value) {
        }

        void writeIRQLatch(ubyte value) {
            this.reload = value;
        }

        void writeIRQReload(ubyte value) {
            this.counter = 0;
        }

        void writeIRQDisable(ubyte value) {
            this.irqEnable = false;
            this.console.cpu.clearIrqSource(IrqSource.External);
        }

        void writeIRQEnable(ubyte value) {
            this.irqEnable = true;
        }

        int prgBankOffset(int index) {
            if (index >= 0x80) {
                index -= 0x100;
            }
            index %= cast(int)(this.cart.prg.length / 0x2000);
            int offset = index * 0x2000;
            if (offset < 0) {
                offset += this.cart.prg.length;
            }
            return offset;
        }

        int chrBankOffset(int index) {
            if (index >= 0x80) {
                index -= 0x100;
            }
            index %= cast(int)(this.cart.chr.length / 0x0400);
            int offset = index * 0x0400;
            if (offset < 0) {
                offset += this.cart.chr.length;
            }
            return offset;
        }

        void updateOffsets() {
            switch (this.prgMode) {
                case 0:
                    this.prgOffsets[0] = this.prgBankOffset(cast(int)this.registers[6]);
                    this.prgOffsets[1] = this.prgBankOffset(cast(int)this.registers[7]);
                    this.prgOffsets[2] = this.prgBankOffset(-2);
                    this.prgOffsets[3] = this.prgBankOffset(-1);
                    break;
                case 1:
                    this.prgOffsets[0] = this.prgBankOffset(-2);
                    this.prgOffsets[1] = this.prgBankOffset(cast(int)this.registers[7]);
                    this.prgOffsets[2] = this.prgBankOffset(cast(int)this.registers[6]);
                    this.prgOffsets[3] = this.prgBankOffset(-1);
                    break;
                default:
                    break;
            }
            switch (this.chrMode) {
                case 0:
                    this.chrOffsets[0] = this.chrBankOffset(cast(int)(this.registers[0] & 0xFE));
                    this.chrOffsets[1] = this.chrBankOffset(cast(int)(this.registers[0] | 0x01));
                    this.chrOffsets[2] = this.chrBankOffset(cast(int)(this.registers[1] & 0xFE));
                    this.chrOffsets[3] = this.chrBankOffset(cast(int)(this.registers[1] | 0x01));
                    this.chrOffsets[4] = this.chrBankOffset(cast(int)this.registers[2]);
                    this.chrOffsets[5] = this.chrBankOffset(cast(int)this.registers[3]);
                    this.chrOffsets[6] = this.chrBankOffset(cast(int)this.registers[4]);
                    this.chrOffsets[7] = this.chrBankOffset(cast(int)this.registers[5]);
                    break;
                case 1:
                    this.chrOffsets[0] = this.chrBankOffset(cast(int)this.registers[2]);
                    this.chrOffsets[1] = this.chrBankOffset(cast(int)this.registers[3]);
                    this.chrOffsets[2] = this.chrBankOffset(cast(int)this.registers[4]);
                    this.chrOffsets[3] = this.chrBankOffset(cast(int)this.registers[5]);
                    this.chrOffsets[4] = this.chrBankOffset(cast(int)(this.registers[0] & 0xFE));
                    this.chrOffsets[5] = this.chrBankOffset(cast(int)(this.registers[0] | 0x01));
                    this.chrOffsets[6] = this.chrBankOffset(cast(int)(this.registers[1] & 0xFE));
                    this.chrOffsets[7] = this.chrBankOffset(cast(int)(this.registers[1] | 0x01));
                    break;
                default:
                    break;
            }
        }
}
