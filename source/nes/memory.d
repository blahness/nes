module nes.memory;

import std.experimental.logger;
import std.format;
import std.stdio;

import nes.console;

interface Memory {
    ubyte read(ushort address);
    void write(ushort address, ubyte value);
}

class MemoryException : Exception
{
    import std.exception : basicExceptionCtors;

    mixin basicExceptionCtors;
}

class CPUMemory : Memory {
    this(Console console) {
        this.console = console;
    }

    ubyte read(ushort address) {
        if (address < 0x2000) {
            return this.console.ram[address % 0x0800];
        }
        else if (address < 0x4000) {
            return this.console.ppu.readRegister(0x2000 + address % 8);
        }
        else if (address == 0x4014) {
            return this.console.ppu.readRegister(address);
        }
        else if (address == 0x4015) {
            return this.console.apu.readRegister(address);
        }
        else if (address == 0x4016) {
            return this.console.controller1.read();
        }
        else if (address == 0x4017) {
            return this.console.controller2.read();
        }
        else if (address < 0x6000) {
            // TODO: I/O registers
        }
        else if (address >= 0x6000) {
            return this.console.mapper.read(address);
        }
        else {
            throw new MemoryException(format("unhandled cpu memory read at address: 0x%04X", address));
        }

        return 0;
    }

    void write(ushort address, ubyte value) {
        if (address < 0x2000) {
            this.console.ram[address % 0x0800] = value;
        }
        else if (address < 0x4000) {
            this.console.ppu.writeRegister(0x2000 + address % 8, value);
        }
        else if (address < 0x4014) {
            this.console.apu.writeRegister(address, value);
        }
        else if (address == 0x4014) {
            this.console.ppu.writeRegister(address, value);
        }
        else if (address == 0x4015) {
            this.console.apu.writeRegister(address, value);
        }
        else if (address == 0x4016) {
            this.console.controller1.write(value);
            this.console.controller2.write(value);
        }
        else if (address == 0x4017) {
            this.console.apu.writeRegister(address, value);
        }
        else if (address < 0x6000) {
            // TODO: I/O registers
        }
        else if (address >= 0x6000) {
            this.console.mapper.write(address, value);
        }
        else {
            throw new MemoryException(format("unhandled cpu memory write at address: 0x%04X", address));
        }
    }

    package Console console;
}

class PPUMemory : Memory {
    this(Console console) {
        this.console = console;
    }

    ubyte read(ushort address) {
        address = address % 0x4000;

        if (address < 0x2000) {
            return this.console.mapper.read(address);
        }
        else if (address < 0x3F00) {
            auto mode = this.console.cartridge.mirror;
            return this.console.ppu.nameTableData[MirrorAddress(mode, address) % 2048];
        }
        else if (address < 0x4000) {
            return this.console.ppu.readPalette(address % 32);
        }
        else {
            throw new MemoryException(format("unhandled ppu memory read at address: 0x%04X", address));
        }
    }

    void write(ushort address, ubyte value) {
        address = address % 0x4000;

        if (address < 0x2000) {
            this.console.mapper.write(address, value);
        }
        else if (address < 0x3F00) {
            auto mode = this.console.cartridge.mirror;
            this.console.ppu.nameTableData[MirrorAddress(mode, address) % 2048] = value;
        }
        else if (address < 0x4000) {
            this.console.ppu.writePalette(address % 32, value);
        }
        else {
            throw new MemoryException(format("unhandled ppu memory write at address: 0x%04X", address));
        }
    }

    private Console console;
}

// Mirroring Modes

enum {
    MirrorHorizontal = 0,
    MirrorVertical   = 1,
    MirrorSingle0    = 2,
    MirrorSingle1    = 3,
    MirrorFour       = 4
}

immutable ushort[4][] MirrorLookup = [
    [0, 0, 1, 1],
    [0, 1, 0, 1],
    [0, 0, 0, 0],
    [1, 1, 1, 1],
    [0, 1, 2, 3]
];

ushort MirrorAddress(ubyte mode, ushort address) {
    address = cast(ushort)(address - 0x2000) % 0x1000;
    auto table = address / 0x0400;
    auto offset = address % 0x0400;

    return cast(ushort)(0x2000 + MirrorLookup[mode][table] * 0x0400 + offset);
}
