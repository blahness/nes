module nes.cpu;

import std.conv;
import std.format;
import std.stdio;

import nes.console;
import nes.memory;

enum CPUFrequency = 1789773;

enum IrqSource : uint {
    External = 1,
    FrameCounter = 2,
    DMC = 4
}

// addressing modes
enum {
    modeAbsolute = 1,
    modeAbsoluteX,
    modeAbsoluteXRead,
    modeAbsoluteY,
    modeAbsoluteYRead,
    modeAccumulator,
    modeImmediate,
    modeImplied,
    modeIndexedIndirect,
    modeIndirect,
    modeIndirectIndexed,
    modeIndirectIndexedRead,
    modeRelative,
    modeZeroPage,
    modeZeroPageX,
    modeZeroPageY
}

// instructionModes indicates the addressing mode for each instruction
ubyte[256] instructionModes = [
    modeImplied,   modeIndexedIndirect,     modeImplied,   modeIndexedIndirect,     modeZeroPage,  modeZeroPage,  modeZeroPage,  modeZeroPage,  modeImplied, modeImmediate,     modeAccumulator, modeImmediate,     modeAbsolute,      modeAbsolute,      modeAbsolute,      modeAbsolute,
    modeRelative,  modeIndirectIndexedRead, modeImplied,   modeIndirectIndexed,     modeZeroPageX, modeZeroPageX, modeZeroPageX, modeZeroPageX, modeImplied, modeAbsoluteYRead, modeImplied,     modeAbsoluteY,     modeAbsoluteXRead, modeAbsoluteXRead, modeAbsoluteX,     modeAbsoluteX,
    modeAbsolute,  modeIndexedIndirect,     modeImplied,   modeIndexedIndirect,     modeZeroPage,  modeZeroPage,  modeZeroPage,  modeZeroPage,  modeImplied, modeImmediate,     modeAccumulator, modeImmediate,     modeAbsolute,      modeAbsolute,      modeAbsolute,      modeAbsolute,
    modeRelative,  modeIndirectIndexedRead, modeImplied,   modeIndirectIndexed,     modeZeroPageX, modeZeroPageX, modeZeroPageX, modeZeroPageX, modeImplied, modeAbsoluteYRead, modeImplied,     modeAbsoluteY,     modeAbsoluteXRead, modeAbsoluteXRead, modeAbsoluteX,     modeAbsoluteX,
    modeImplied,   modeIndexedIndirect,     modeImplied,   modeIndexedIndirect,     modeZeroPage,  modeZeroPage,  modeZeroPage,  modeZeroPage,  modeImplied, modeImmediate,     modeAccumulator, modeImmediate,     modeAbsolute,      modeAbsolute,      modeAbsolute,      modeAbsolute,
    modeRelative,  modeIndirectIndexedRead, modeImplied,   modeIndirectIndexed,     modeZeroPageX, modeZeroPageX, modeZeroPageX, modeZeroPageX, modeImplied, modeAbsoluteYRead, modeImplied,     modeAbsoluteY,     modeAbsoluteXRead, modeAbsoluteXRead, modeAbsoluteX,     modeAbsoluteX,
    modeImplied,   modeIndexedIndirect,     modeImplied,   modeIndexedIndirect,     modeZeroPage,  modeZeroPage,  modeZeroPage,  modeZeroPage,  modeImplied, modeImmediate,     modeAccumulator, modeImmediate,     modeIndirect,      modeAbsolute,      modeAbsolute,      modeAbsolute,
    modeRelative,  modeIndirectIndexedRead, modeImplied,   modeIndirectIndexed,     modeZeroPageX, modeZeroPageX, modeZeroPageX, modeZeroPageX, modeImplied, modeAbsoluteYRead, modeImplied,     modeAbsoluteY,     modeAbsoluteXRead, modeAbsoluteXRead, modeAbsoluteX,     modeAbsoluteX,
    modeImmediate, modeIndexedIndirect,     modeImmediate, modeIndexedIndirect,     modeZeroPage,  modeZeroPage,  modeZeroPage,  modeZeroPage,  modeImplied, modeImmediate,     modeImplied,     modeImmediate,     modeAbsolute,      modeAbsolute,      modeAbsolute,      modeAbsolute,
    modeRelative,  modeIndirectIndexed,     modeImplied,   modeIndirectIndexed,     modeZeroPageX, modeZeroPageX, modeZeroPageY, modeZeroPageY, modeImplied, modeAbsoluteY,     modeImplied,     modeAbsoluteY,     modeAbsoluteX,     modeAbsoluteX,     modeAbsoluteY,     modeAbsoluteY,
    modeImmediate, modeIndexedIndirect,     modeImmediate, modeIndexedIndirect,     modeZeroPage,  modeZeroPage,  modeZeroPage,  modeZeroPage,  modeImplied, modeImmediate,     modeImplied,     modeImmediate,     modeAbsolute,      modeAbsolute,      modeAbsolute,      modeAbsolute,
    modeRelative,  modeIndirectIndexedRead, modeImplied,   modeIndirectIndexedRead, modeZeroPageX, modeZeroPageX, modeZeroPageY, modeZeroPageY, modeImplied, modeAbsoluteYRead, modeImplied,     modeAbsoluteYRead, modeAbsoluteXRead, modeAbsoluteXRead, modeAbsoluteYRead, modeAbsoluteYRead,
    modeImmediate, modeIndexedIndirect,     modeImmediate, modeIndexedIndirect,     modeZeroPage,  modeZeroPage,  modeZeroPage,  modeZeroPage,  modeImplied, modeImmediate,     modeImplied,     modeImmediate,     modeAbsolute,      modeAbsolute,      modeAbsolute,      modeAbsolute,
    modeRelative,  modeIndirectIndexedRead, modeImplied,   modeIndirectIndexed,     modeZeroPageX, modeZeroPageX, modeZeroPageX, modeZeroPageX, modeImplied, modeAbsoluteYRead, modeImplied,     modeAbsoluteY,     modeAbsoluteXRead, modeAbsoluteXRead, modeAbsoluteX,     modeAbsoluteX,
    modeImmediate, modeIndexedIndirect,     modeImmediate, modeIndexedIndirect,     modeZeroPage,  modeZeroPage,  modeZeroPage,  modeZeroPage,  modeImplied, modeImmediate,     modeImplied,     modeImmediate,     modeAbsolute,      modeAbsolute,      modeAbsolute,      modeAbsolute,
    modeRelative,  modeIndirectIndexedRead, modeImplied,   modeIndirectIndexed,     modeZeroPageX, modeZeroPageX, modeZeroPageX, modeZeroPageX, modeImplied, modeAbsoluteYRead, modeImplied,     modeAbsoluteY,     modeAbsoluteXRead, modeAbsoluteXRead, modeAbsoluteX,     modeAbsoluteX
];

// instructionSizes indicates the size of each instruction in bytes
ubyte[256] instructionSizes = [
    1, 2, 1, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3,
    2, 2, 0, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3,
    3, 2, 0, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3,
    2, 2, 0, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3,
    1, 2, 0, 2, 2, 2, 2, 2, 1, 2, 1, 2, 4, 3, 3, 3,
    2, 2, 0, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3,
    1, 2, 0, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3,
    2, 2, 0, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3,
    2, 2, 0, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3,
    2, 2, 0, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3,
    2, 2, 0, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 2, 1, 2, 3, 3, 3, 3,
    2, 2, 1, 2, 2, 2, 2, 2, 1, 3, 1, 3, 3, 3, 3, 3
];

// instructionNames indicates the name of each instruction
string[256] instructionNames = [
    "BRK", "ORA", "KIL", "SLO", "NOP", "ORA", "ASL", "SLO", "PHP", "ORA", "ASL", "AAC", "NOP", "ORA", "ASL", "SLO",
    "BPL", "ORA", "KIL", "SLO", "NOP", "ORA", "ASL", "SLO", "CLC", "ORA", "NOP", "SLO", "NOP", "ORA", "ASL", "SLO",
    "JSR", "AND", "KIL", "RLA", "BIT", "AND", "ROL", "RLA", "PLP", "AND", "ROL", "AAC", "BIT", "AND", "ROL", "RLA",
    "BMI", "AND", "KIL", "RLA", "NOP", "AND", "ROL", "RLA", "SEC", "AND", "NOP", "RLA", "NOP", "AND", "ROL", "RLA",
    "RTI", "EOR", "KIL", "SRE", "NOP", "EOR", "LSR", "SRE", "PHA", "EOR", "LSR", "ASR", "JMP", "EOR", "LSR", "SRE",
    "BVC", "EOR", "KIL", "SRE", "NOP", "EOR", "LSR", "SRE", "CLI", "EOR", "NOP", "SRE", "NOP", "EOR", "LSR", "SRE",
    "RTS", "ADC", "KIL", "RRA", "NOP", "ADC", "ROR", "RRA", "PLA", "ADC", "ROR", "ARR", "JMP", "ADC", "ROR", "RRA",
    "BVS", "ADC", "KIL", "RRA", "NOP", "ADC", "ROR", "RRA", "SEI", "ADC", "NOP", "RRA", "NOP", "ADC", "ROR", "RRA",
    "NOP", "STA", "NOP", "SAX", "STY", "STA", "STX", "SAX", "DEY", "NOP", "TXA", "XAA", "STY", "STA", "STX", "SAX",
    "BCC", "STA", "KIL", "AHX", "STY", "STA", "STX", "SAX", "TYA", "STA", "TXS", "TAS", "SYA", "STA", "SXA", "AHX",
    "LDY", "LDA", "LDX", "LAX", "LDY", "LDA", "LDX", "LAX", "TAY", "LDA", "TAX", "LAX", "LDY", "LDA", "LDX", "LAX",
    "BCS", "LDA", "KIL", "LAX", "LDY", "LDA", "LDX", "LAX", "CLV", "LDA", "ATX", "LAS", "LDY", "LDA", "LDX", "LAX",
    "CPY", "CMP", "NOP", "DCP", "CPY", "CMP", "DEC", "DCP", "INY", "CMP", "DEX", "AXS", "CPY", "CMP", "DEC", "DCP",
    "BNE", "CMP", "KIL", "DCP", "NOP", "CMP", "DEC", "DCP", "CLD", "CMP", "NOP", "DCP", "NOP", "CMP", "DEC", "DCP",
    "CPX", "SBC", "NOP", "ISC", "CPX", "SBC", "INC", "ISC", "INX", "SBC", "NOP", "SBC", "CPX", "SBC", "INC", "ISC",
    "BEQ", "SBC", "KIL", "ISC", "NOP", "SBC", "INC", "ISC", "SED", "SBC", "NOP", "ISC", "NOP", "SBC", "INC", "ISC"
];

// stepInfo contains information that the instruction functions use
struct stepInfo {
    ushort address;
    ushort pc;
    ubyte mode;
}

alias void delegate(stepInfo*) InstructionFuncType;

// pagesDiffer returns true if the two addresses reference different pages
bool pagesDiffer(ushort a, ushort b) {
    return (a & 0xFF00) != (b & 0xFF00);
}

class CPU : CPUMemory {
    ulong cycles; // number of cycles
    ushort pc;    // program counter
    ubyte sp;     // stack pointer
    ubyte a;      // accumulator
    ubyte x;      // x register
    ubyte y;      // y register
    ubyte c;      // carry flag
    ubyte z;      // zero flag
    ubyte i;      // interrupt disable flag
    ubyte d;      // decimal mode flag
    ubyte b;      // break command flag
    ubyte u;      // unused flag
    ubyte v;      // overflow flag
    ubyte n;      // negative flag

    int stall;    // number of cycles to stall

    this(Console console) {
        super(console);
        this.createTable();
        this.reset();
    }

    // reset resets the CPU to its initial powerup state
    void reset() {
        this.pc = this.read16(0xFFFC);
        this.sp = 0xFD;
        this.setFlags(0x24);

        this.nmiFlag = false;
        this.irqFlag = 0;

        this.cycles = 0;
        this.stall = 0;

        this.spriteDmaTransferRunning = false;
        this.spriteDmaCounter = 0;
    }

    string disassembleInstruction() {
        auto opcode = this.read(this.pc);
        auto name = instructionNames[opcode];
        auto mode = instructionModes[opcode];

        string r;

        switch (mode) {
            case modeImplied:
                r = name;
                break;

            case modeAccumulator:
                r = name ~ " A";
                break;

            case modeImmediate:
                auto address = this.read(cast(ushort)(this.pc + 1));

                r = format("%s #$%02X", name, address);
                break;

            case modeZeroPage:
                auto address = this.read(cast(ushort)(this.pc + 1));

                r = format("%s $%02X", name, address);
                break;

            case modeZeroPageX:
                auto address = this.read(cast(ushort)(this.pc + 1));

                r = format("%s $%02X,X", name, address);
                break;

            case modeZeroPageY:
                auto address = this.read(cast(ushort)(this.pc + 1));

                r = format("%s $%02X,Y", name, address);
                break;

            case modeRelative:
                auto offset = this.read(cast(ushort)(this.pc + 1));
                ushort address;

                if (offset < 0x80) {
                    address = cast(ushort)(this.pc + 2 + offset);
                } else {
                    address = cast(ushort)(this.pc + 2 + offset - 0x100);
                }

                //r = format("%s *%s", name, cast(byte)offset);
                r = format("%s $%04X", name, address);
                break;

            case modeAbsolute:
                auto address = this.read16(cast(ushort)(this.pc + 1));

                r = format("%s $%04X", name, address);
                break;

            case modeAbsoluteX, modeAbsoluteXRead:
                auto address = this.read16(cast(ushort)(this.pc + 1));

                r = format("%s $%04X,X", name, address);
                break;

            case modeAbsoluteY, modeAbsoluteYRead:
                auto address = this.read16(cast(ushort)(this.pc + 1));

                r = format("%s $%04X,Y", name, address);
                break;

            case modeIndirect:
                auto address = this.read16(cast(ushort)(this.pc + 1));

                r = format("%s ($%04X)", name, address);
                break;

            case modeIndexedIndirect:
                auto address = this.read(cast(ushort)(this.pc + 1));

                r = format("%s ($%02X,X)", name, address);
                break;

            case modeIndirectIndexed, modeIndirectIndexedRead:
                auto address = this.read(cast(ushort)(this.pc + 1));

                r = format("%s ($%02X),Y", name, address);
                break;

            default:
                break;
        }

        return r;
    }

    // printInstruction prints the current CPU state
    void printInstruction() {
        auto opcode = this.read(this.pc);
        auto bytes = instructionSizes[opcode];
        auto name = instructionNames[opcode];
        auto w0 = format("%02X", this.read(this.pc + 0));
        auto w1 = format("%02X", this.read(cast(ushort)(this.pc + 1)));
        auto w2 = format("%02X", this.read(cast(ushort)(this.pc + 2)));
        if (bytes < 2) {
            w1 = "  ";
        }
        if (bytes < 3) {
            w2 = "  ";
        }
        writef(
            "%4X  %s %s %s  %s %28s" ~
            "A:%02X X:%02X Y:%02X P:%02X SP:%02X CYC:%3d\n",
            this.pc, w0, w1, w2, name, "",
            this.a, this.x, this.y, this.flags(), this.sp, (this.cycles * 3) % 341);
    }

    // flags returns the processor status flags
    ubyte flags() {
        ubyte  flags;
        flags |= this.c << 0;
        flags |= this.z << 1;
        flags |= this.i << 2;
        flags |= this.d << 3;
        flags |= this.b << 4;
        flags |= this.u << 5;
        flags |= this.v << 6;
        flags |= this.n << 7;
        return flags;
    }

    // setFlags sets the processor status flags
    void setFlags(ubyte flags) {
        this.c = (flags >> 0) & 1;
        this.z = (flags >> 1) & 1;
        this.i = (flags >> 2) & 1;
        this.d = (flags >> 3) & 1;
        this.b = (flags >> 4) & 1;
        this.u = (flags >> 5) & 1;
        this.v = (flags >> 6) & 1;
        this.n = (flags >> 7) & 1;
    }

    // read16 reads two bytes using Read to return a double-word value
    ushort read16(ushort address) {
        auto lo = cast(ushort)this.read(address);
        auto hi = cast(ushort)this.read(cast(ushort)(address + 1));

        return cast(ushort)(hi << 8 | lo);
    }

    // Step executes a single CPU instruction
    void step() {
        while (this.stall > 0) {
            this.stall--;
            this.cycles++;

            foreach (_; 0 .. 3) {
                this.console.ppu.step();
                this.console.mapper.step();
            }

            this.console.apu.step();
        }

        auto cycles = this.cycles;

        auto opcode = this.memoryRead(this.pc);
        auto mode = instructionModes[opcode];
        this.pc++;

        ushort address;
        bool pageCrossed;
        switch (mode) {
            case modeAbsolute:
                address = this.memoryRead16(this.pc);
                this.pc += 2;
                break;
            case modeAbsoluteX:
                address = cast(ushort)(this.memoryRead16(this.pc) + this.x);
                this.pc += 2;
                this.memoryRead(address); // dummy read
                break;
            case modeAbsoluteXRead:
                address = cast(ushort)(this.memoryRead16(this.pc) + this.x);
                this.pc += 2;

                pageCrossed = pagesDiffer(cast(ushort)(address - this.x), address);

                if (pageCrossed)
                    this.memoryRead(cast(ushort)(address - 0x100)); // dummy read
                break;
            case modeAbsoluteY:
                address = cast(ushort)(this.memoryRead16(this.pc) + this.y);
                this.pc += 2;
                this.memoryRead(address); // dummy read
                break;
            case modeAbsoluteYRead:
                address = cast(ushort)(this.memoryRead16(this.pc) + this.y);
                this.pc += 2;

                pageCrossed = pagesDiffer(cast(ushort)(address - this.y), address);

                if (pageCrossed)
                    this.memoryRead(cast(ushort)(address - 0x100)); // dummy read
                break;
            case modeAccumulator:
                this.memoryRead(this.pc); // dummy read
                address = 0;
                break;
            case modeImmediate:
                address = this.pc;
                this.pc++;
                break;
            case modeImplied:
                this.memoryRead(this.pc); // dummy read
                address = 0;
                break;
            // Indirect,X
            case modeIndexedIndirect:
                ubyte zero = this.memoryRead(this.pc);
                this.pc++;
                this.memoryRead(zero); // dummy read
                zero += this.x;
                if (zero == 0xFF) {
                    address = this.memoryRead(0xFF) | this.memoryRead(0x00) << 8;
                } else {
                    address = this.memoryRead16(zero);
                }
                break;
            case modeIndirect:
                // JMP is the ONLY opcode to use this addressing mode
                address = this.memoryRead16(this.pc);
                this.pc += 2;
                if((address & 0xFF) == 0xFF) {
                    auto lo = this.memoryRead(address);
                    auto hi = this.memoryRead(cast(ushort)(address - 0xFF));
                    address = (lo | hi << 8);
                } else {
                    address = this.memoryRead16(address);
                }

                break;
            // Indirect,Y
            case modeIndirectIndexed:
                ubyte zero = this.memoryRead(this.pc);
                this.pc++;

                if (zero == 0xFF) {
                    address = this.memoryRead(0xFF) | this.memoryRead(0x00) << 8;
                } else {
                    address = this.memoryRead16(zero);
                }

                address += this.y;

                this.memoryRead(address); // dummy read
                break;
            case modeIndirectIndexedRead:
                ubyte zero = this.memoryRead(this.pc);
                this.pc++;

                if (zero == 0xFF) {
                    address = this.memoryRead(0xFF) | this.memoryRead(0x00) << 8;
                } else {
                    address = this.memoryRead16(zero);
                }

                address += this.y;

                pageCrossed = pagesDiffer(cast(ushort)(address - this.y), address);

                if (pageCrossed)
                    this.memoryRead(cast(ushort)(address - 0x100)); // dummy read

                break;
            case modeRelative:
                auto offset = cast(ushort)this.memoryRead(this.pc);
                this.pc++;
                if (offset < 0x80) {
                    address = cast(ushort)(this.pc + offset);
                } else {
                    address = cast(ushort)(this.pc + offset - 0x100);
                }
                break;
            case modeZeroPage:
                address = cast(ushort)this.memoryRead(this.pc);
                this.pc++;
                break;
            case modeZeroPageX:
                address = cast(ushort)(this.memoryRead(this.pc) + this.x) & 0xff;
                this.pc++;
                this.memoryRead(cast(ushort)(address - this.x)); // dummy read
                break;
            case modeZeroPageY:
                address = cast(ushort)(this.memoryRead(this.pc) + this.y) & 0xff;
                this.pc++;
                this.memoryRead(cast(ushort)(address - this.y)); // dummy read
                break;
            default:
                break;
        }

        auto info = stepInfo(address, this.pc, mode);
        this.table[opcode](&info);

        if (prevRunIrq) {
            auto startCycles = this.cycles;
            
            this.irq();

            assert(this.cycles - startCycles == 7);
        }
    }

    void setNmiFlag() {
        this.nmiFlag = true;
    }

    void clearNmiFlag() {
        this.nmiFlag = false;
    }

    void addIrqSource(IrqSource source) {
        this.irqFlag |= source;
    }

    void clearIrqSource(IrqSource source) {
        this.irqFlag &= ~source;
    }

    bool hasIrqSource(IrqSource source) {
        return (this.irqFlag & source) != 0;
    }

    void save(string[string] state) {
        state["cpu.cycles"] = to!string(this.cycles);
        state["cpu.pc"] = to!string(this.pc);
        state["cpu.sp"] = to!string(this.sp);
        state["cpu.a"] = to!string(this.a);
        state["cpu.x"] = to!string(this.x);
        state["cpu.y"] = to!string(this.y);
        state["cpu.c"] = to!string(this.c);
        state["cpu.z"] = to!string(this.z);
        state["cpu.i"] = to!string(this.i);
        state["cpu.d"] = to!string(this.d);
        state["cpu.b"] = to!string(this.b);
        state["cpu.u"] = to!string(this.u);
        state["cpu.v"] = to!string(this.v);
        state["cpu.n"] = to!string(this.n);
        state["cpu.stall"] = to!string(this.stall);

        state["cpu.nmiFlag"] = to!string(this.nmiFlag);
        state["cpu.irqFlag"] = to!string(this.irqFlag);
        state["cpu.runIrq"] = to!string(this.runIrq);
        state["cpu.prevRunIrq"] = to!string(this.prevRunIrq);
        state["cpu.spriteDmaTransferRunning"] = to!string(this.spriteDmaTransferRunning);
        state["cpu.spriteDmaCounter"] = to!string(this.spriteDmaCounter);
    }

    void load(string[string] state) {
        this.cycles = to!ulong(state["cpu.cycles"]);
        this.pc = to!ushort(state["cpu.pc"]);
        this.sp = to!ubyte(state["cpu.sp"]);
        this.a = to!ubyte(state["cpu.a"]);
        this.x = to!ubyte(state["cpu.x"]);
        this.y = to!ubyte(state["cpu.y"]);
        this.c = to!ubyte(state["cpu.c"]);
        this.z = to!ubyte(state["cpu.z"]);
        this.i = to!ubyte(state["cpu.i"]);
        this.d = to!ubyte(state["cpu.d"]);
        this.b = to!ubyte(state["cpu.b"]);
        this.u = to!ubyte(state["cpu.u"]);
        this.v = to!ubyte(state["cpu.v"]);
        this.n = to!ubyte(state["cpu.n"]);
        this.stall = to!int(state["cpu.stall"]);

        this.nmiFlag = to!bool(state["cpu.nmiFlag"]);
        this.irqFlag = to!uint(state["cpu.irqFlag"]);
        this.runIrq = to!bool(state["cpu.runIrq"]);
        this.prevRunIrq = to!bool(state["cpu.prevRunIrq"]);
        this.spriteDmaTransferRunning = to!bool(state["cpu.spriteDmaTransferRunning"]);
        this.spriteDmaCounter = to!ushort(state["cpu.spriteDmaCounter"]);
    }

    package:
        void spriteDmaTransfer(ubyte value) {
            this.spriteDmaTransferRunning = true;
            
            if ((this.cycles & 1) == 0) {
                this.memoryRead(this.pc); // dummy read
            }

            this.memoryRead(this.pc); // dummy read

            this.spriteDmaCounter = 256;

            for (int i = 0; i < 0x100; i++) {
                auto readValue = this.memoryRead(cast(ushort)(value * 0x100 + i));
                
                this.memoryWrite(0x2004, readValue);

                this.spriteDmaCounter--;
            }
            
            this.spriteDmaTransferRunning = false;
        }

    private:
        bool nmiFlag;
        uint irqFlag;
        bool runIrq, prevRunIrq;
        InstructionFuncType[256] table;
        bool   spriteDmaTransferRunning;
        ushort spriteDmaCounter;

        // createTable builds a function table for each instruction
        void createTable() {
            this.table = [
                &this.brk, &this.ora, &this.kil, &this.slo, &this.nop, &this.ora, &this.asl, &this.slo, &this.php, &this.ora, &this.asl, &this.aac, &this.nop, &this.ora, &this.asl, &this.slo,
                &this.bpl, &this.ora, &this.kil, &this.slo, &this.nop, &this.ora, &this.asl, &this.slo, &this.clc, &this.ora, &this.nop, &this.slo, &this.nop, &this.ora, &this.asl, &this.slo,
                &this.jsr, &this.and, &this.kil, &this.rla, &this.bit, &this.and, &this.rol, &this.rla, &this.plp, &this.and, &this.rol, &this.aac, &this.bit, &this.and, &this.rol, &this.rla,
                &this.bmi, &this.and, &this.kil, &this.rla, &this.nop, &this.and, &this.rol, &this.rla, &this.sec, &this.and, &this.nop, &this.rla, &this.nop, &this.and, &this.rol, &this.rla,
                &this.rti, &this.eor, &this.kil, &this.sre, &this.nop, &this.eor, &this.lsr, &this.sre, &this.pha, &this.eor, &this.lsr, &this.asr, &this.jmp, &this.eor, &this.lsr, &this.sre,
                &this.bvc, &this.eor, &this.kil, &this.sre, &this.nop, &this.eor, &this.lsr, &this.sre, &this.cli, &this.eor, &this.nop, &this.sre, &this.nop, &this.eor, &this.lsr, &this.sre,
                &this.rts, &this.adc, &this.kil, &this.rra, &this.nop, &this.adc, &this.ror, &this.rra, &this.pla, &this.adc, &this.ror, &this.arr, &this.jmp, &this.adc, &this.ror, &this.rra,
                &this.bvs, &this.adc, &this.kil, &this.rra, &this.nop, &this.adc, &this.ror, &this.rra, &this.sei, &this.adc, &this.nop, &this.rra, &this.nop, &this.adc, &this.ror, &this.rra,
                &this.nop, &this.sta, &this.nop, &this.sax, &this.sty, &this.sta, &this.stx, &this.sax, &this.dey, &this.nop, &this.txa, &this.xaa, &this.sty, &this.sta, &this.stx, &this.sax,
                &this.bcc, &this.sta, &this.kil, &this.ahx, &this.sty, &this.sta, &this.stx, &this.sax, &this.tya, &this.sta, &this.txs, &this.tas, &this.sya, &this.sta, &this.sxa, &this.ahx,
                &this.ldy, &this.lda, &this.ldx, &this.lax, &this.ldy, &this.lda, &this.ldx, &this.lax, &this.tay, &this.lda, &this.tax, &this.atx, &this.ldy, &this.lda, &this.ldx, &this.lax,
                &this.bcs, &this.lda, &this.kil, &this.lax, &this.ldy, &this.lda, &this.ldx, &this.lax, &this.clv, &this.lda, &this.tsx, &this.las, &this.ldy, &this.lda, &this.ldx, &this.lax,
                &this.cpy, &this.cmp, &this.nop, &this.dcp, &this.cpy, &this.cmp, &this.dec, &this.dcp, &this.iny, &this.cmp, &this.dex, &this.axs, &this.cpy, &this.cmp, &this.dec, &this.dcp,
                &this.bne, &this.cmp, &this.kil, &this.dcp, &this.nop, &this.cmp, &this.dec, &this.dcp, &this.cld, &this.cmp, &this.nop, &this.dcp, &this.nop, &this.cmp, &this.dec, &this.dcp,
                &this.cpx, &this.sbc, &this.nop, &this.isc, &this.cpx, &this.sbc, &this.inc, &this.isc, &this.inx, &this.sbc, &this.nop, &this.sbc, &this.cpx, &this.sbc, &this.inc, &this.isc,
                &this.beq, &this.sbc, &this.kil, &this.isc, &this.nop, &this.sbc, &this.inc, &this.isc, &this.sed, &this.sbc, &this.nop, &this.isc, &this.nop, &this.sbc, &this.inc, &this.isc
            ];
        }

        ubyte memoryRead(ushort address) {
            this.nextCycle();

            return this.read(address);
        }

        ushort memoryRead16(ushort address) {
            auto lo = cast(ushort)this.memoryRead(address);
            auto hi = cast(ushort)this.memoryRead(cast(ushort)(address + 1));

            return cast(ushort)(hi << 8 | lo);
        }

        void memoryWrite(ushort address, ubyte value) {
            this.nextCycle();

            this.write(address, value);
        }

        void nextCycle() {
            this.cycles++;

            foreach (_; 0 .. 3) {
                this.console.ppu.step();
                this.console.mapper.step();
            }

            this.console.apu.step();

            if (!this.spriteDmaTransferRunning) {
                this.prevRunIrq = this.runIrq;
                this.runIrq = this.nmiFlag || (this.irqFlag && this.i == 0);
            }
        }

        // addBranchCycles adds a cycle for taking a branch and adds another cycle
        // if the branch jumps to a new page
        void addBranchCycles(stepInfo* info) {
            if(runIrq && !prevRunIrq) {
                runIrq = false;
            }

            this.memoryRead(this.pc); // dummy read
            if (pagesDiffer(info.pc, info.address)) {
                this.memoryRead(this.pc); // dummy read
            }
        }

        void compare(ubyte a, ubyte b) {
            this.setZN(cast(ubyte)(a - b));
            if (a >= b) {
                this.c = 1;
            } else {
                this.c = 0;
            }
        }

        // push pushes a byte onto the stack
        void push(ubyte value) {
            this.memoryWrite(0x100 + cast(ushort)this.sp, value);
            this.sp--;
        }

        // pull pops a byte from the stack
        ubyte pull() {
            this.sp++;
            return this.memoryRead(0x100 + cast(ushort)this.sp);
        }

        // push16 pushes two bytes onto the stack
        void push16(ushort value) {
            auto hi = cast(ubyte)(value >> 8);
            auto lo = cast(ubyte)(value & 0xFF);
            this.push(hi);
            this.push(lo);
        }

        // pull16 pops two bytes from the stack
        ushort pull16() {
            auto lo = cast(ushort)this.pull();
            auto hi = cast(ushort)this.pull();
            return cast(ushort)(hi << 8 | lo);
        }

        // setZ sets the zero flag if the argument is zero
        void setZ(ubyte value) {
            if (value == 0) {
                this.z = 1;
            } else {
                this.z = 0;
            }
        }

        // setN sets the negative flag if the argument is negative (high bit is set)
        void setN(ubyte value) {
            if ((value & 0x80) != 0) {
                this.n = 1;
            } else {
                this.n = 0;
            }
        }

        // setZN sets the zero flag and the negative flag
        void setZN(ubyte value) {
            this.setZ(value);
            this.setN(value);
        }

        // NMI - Non-Maskable Interrupt
        void nmi() {
            this.memoryRead(this.pc); // dummy read
            this.memoryRead(this.pc); // dummy read
            this.push16(this.pc);
            this.push(this.flags());
            this.i = 1;
            this.pc = this.memoryRead16(0xFFFA);
        }

        // IRQ - IRQ Interrupt
        void irq() {
            this.memoryRead(this.pc); // dummy read
            this.memoryRead(this.pc); // dummy read
            this.push16(this.pc);

            if (this.nmiFlag) {
                this.push(this.flags());
                this.i = 1;
                this.pc = this.memoryRead16(0xFFFA);
                this.nmiFlag = false;
            } else {
                this.push(this.flags());
                this.i = 1;
                this.pc = this.memoryRead16(0xFFFE);
            }
        }

        // ADC - Add with Carry
        void adc(stepInfo* info) {
            auto a = this.a;
            auto b = this.memoryRead(info.address);
            auto c = this.c;
            this.a = cast(ubyte)(a + b + c);
            this.setZN(this.a);
            if (cast(int)a + cast(int)b + cast(int)c > 0xFF) {
                this.c = 1;
            } else {
                this.c = 0;
            }
            if (((a ^ b) & 0x80) == 0 && ((a ^ this.a) & 0x80) != 0) {
                this.v = 1;
            } else {
                this.v = 0;
            }
        }

        // AND - Logical AND
        void and(stepInfo* info) {
            this.a = this.a & this.memoryRead(info.address);
            this.setZN(this.a);
        }

        // ASL - Arithmetic Shift Left
        void asl(stepInfo* info) {
            if (info.mode == modeAccumulator) {
                this.c = (this.a >> 7) & 1;
                this.a <<= 1;
                this.setZN(this.a);
            } else {
                auto value = this.memoryRead(info.address);
                this.memoryWrite(info.address, value); // dummy write
                this.c = (value >> 7) & 1;
                value <<= 1;
                this.setZN(value);
                this.memoryWrite(info.address, value);
            }
        }

        // BCC - Branch if Carry Clear
        void bcc(stepInfo* info) {
            if (this.c == 0) {
                this.pc = info.address;
                this.addBranchCycles(info);
            }
        }

        // BCS - Branch if Carry Set
        void bcs(stepInfo* info) {
            if (this.c != 0) {
                this.pc = info.address;
                this.addBranchCycles(info);
            }
        }

        // BEQ - Branch if Equal
        void beq(stepInfo* info) {
            if (this.z != 0) {
                this.pc = info.address;
                this.addBranchCycles(info);
            }
        }

        // BIT - Bit Test
        void bit(stepInfo* info) {
            auto value = this.memoryRead(info.address);
            this.z = this.v = this.n = 0;
            this.v = (value >> 6) & 1;
            this.setZ(value & this.a);
            this.setN(value);
        }

        // BMI - Branch if Minus
        void bmi(stepInfo* info) {
            if (this.n != 0) {
                this.pc = info.address;
                this.addBranchCycles(info);
            }
        }

        // BNE - Branch if Not Equal
        void bne(stepInfo* info) {
            if (this.z == 0) {
                this.pc = info.address;
                this.addBranchCycles(info);
            }
        }

        // BPL - Branch if Positive
        void bpl(stepInfo* info) {
            if (this.n == 0) {
                this.pc = info.address;
                this.addBranchCycles(info);
            }
        }

        // BRK - Force Interrupt
        void brk(stepInfo* info) {
            this.push16(cast(ushort)(this.pc + 1));

            if (this.nmiFlag) {
                this.push(this.flags() | 0x10);
                this.i = 1;

                this.pc = this.memoryRead16(0xFFFA);
            } else {
                this.push(this.flags() | 0x10);
                this.i = 1;

                this.pc = this.memoryRead16(0xFFFE);
            }

            this.prevRunIrq = false;
        }

        // BVC - Branch if Overflow Clear
        void bvc(stepInfo* info) {
            if (this.v == 0) {
                this.pc = info.address;
                this.addBranchCycles(info);
            }
        }

        // BVS - Branch if Overflow Set
        void bvs(stepInfo* info) {
            if (this.v != 0) {
                this.pc = info.address;
                this.addBranchCycles(info);
            }
        }

        // CLC - Clear Carry Flag
        void clc(stepInfo* info) {
            this.c = 0;
        }

        // CLD - Clear Decimal Mode
        void cld(stepInfo* info) {
            this.d = 0;
        }

        // CLI - Clear Interrupt Disable
        void cli(stepInfo* info) {
            this.i = 0;
        }

        // CLV - Clear Overflow Flag
        void clv(stepInfo* info) {
            this.v = 0;
        }

        // CMP - Compare
        void cmp(stepInfo* info) {
            auto value = this.memoryRead(info.address);
            this.compare(this.a, value);
        }

        // CPX - Compare X Register
        void cpx(stepInfo* info) {
            auto value = this.memoryRead(info.address);
            this.compare(this.x, value);
        }

        // CPY - Compare Y Register
        void cpy(stepInfo* info) {
            auto value = this.memoryRead(info.address);
            this.compare(this.y, value);
        }

        // DEC - Decrement Memory
        void dec(stepInfo* info) {
            auto value = this.memoryRead(info.address);
            this.memoryWrite(info.address, value); // dummy write
            value--;
            this.setZN(value);
            this.memoryWrite(info.address, value);
        }

        // DEX - Decrement X Register
        void dex(stepInfo* info) {
            this.x--;
            this.setZN(this.x);
        }

        // DEY - Decrement Y Register
        void dey(stepInfo* info) {
            this.y--;
            this.setZN(this.y);
        }

        // EOR - Exclusive OR
        void eor(stepInfo* info) {
            this.a = this.a ^ this.memoryRead(info.address);
            this.setZN(this.a);
        }

        // INC - Increment Memory
        void inc(stepInfo* info) {
            auto value = this.memoryRead(info.address);
            this.memoryWrite(info.address, value); // dummy write
            value++;
            this.setZN(value);
            this.memoryWrite(info.address, value);
        }

        // INX - Increment X Register
        void inx(stepInfo* info) {
            this.x++;
            this.setZN(this.x);
        }

        // INY - Increment Y Register
        void iny(stepInfo* info) {
            this.y++;
            this.setZN(this.y);
        }

        // JMP - Jump
        void jmp(stepInfo* info) {
            this.pc = info.address;
        }

        // JSR - Jump to Subroutine
        void jsr(stepInfo* info) {
            this.memoryRead(this.pc); // dummy read
            this.push16(cast(ushort)(this.pc - 1));
            this.pc = info.address;
        }

        // LDA - Load Accumulator
        void lda(stepInfo* info) {
            this.a = this.memoryRead(info.address);
            this.setZN(this.a);
        }

        // LDX - Load X Register
        void ldx(stepInfo* info) {
            this.x = this.memoryRead(info.address);
            this.setZN(this.x);
        }

        // LDY - Load Y Register
        void ldy(stepInfo* info) {
            this.y = this.memoryRead(info.address);
            this.setZN(this.y);
        }

        // LSR - Logical Shift Right
        void lsr(stepInfo* info) {
            if (info.mode == modeAccumulator) {
                this.c = this.a & 1;
                this.a >>= 1;
                this.setZN(this.a);
            } else {
                auto value = this.memoryRead(info.address);
                this.memoryWrite(info.address, value); // dummy write
                this.c = value & 1;
                value >>= 1;
                this.setZN(value);
                this.memoryWrite(info.address, value);
            }
        }

        // NOP - No Operation
        void nop(stepInfo* info) {
            if (info.mode != modeAccumulator &&
                info.mode != modeImplied &&
                info.mode != modeRelative)
            {
                this.memoryRead(info.address); // dummy read
            }
        }

        // ORA - Logical Inclusive OR
        void ora(stepInfo* info) {
            this.a = this.a | this.memoryRead(info.address);
            this.setZN(this.a);
        }

        // PHA - Push Accumulator
        void pha(stepInfo* info) {
            this.push(this.a);
        }

        // PHP - Push Processor Status
        void php(stepInfo* info) {
            this.push(this.flags() | 0x10);
        }

        // PLA - Pull Accumulator
        void pla(stepInfo* info) {
            this.memoryRead(this.pc); // dummy read
            this.a = this.pull();
            this.setZN(this.a);
        }

        // PLP - Pull Processor Status
        void plp(stepInfo* info) {
            this.memoryRead(this.pc); // dummy read
            this.setFlags((this.pull() & 0xCF) | 0x20);
        }

        // ROL - Rotate Left
        void rol(stepInfo* info) {
            if (info.mode == modeAccumulator) {
                auto c = this.c;
                this.c = cast(ubyte)((this.a >> 7) & 1);
                this.a = cast(ubyte)((this.a << 1) | c);
                this.setZN(this.a);
            } else {
                auto c = this.c;
                auto value = this.memoryRead(info.address);
                this.memoryWrite(info.address, value); // dummy write
                this.c = (value >> 7) & 1;
                value = cast(ubyte)((value << 1) | c);
                this.setZN(value);
                this.memoryWrite(info.address, value);
            }
        }

        // ROR - Rotate Right
        void ror(stepInfo* info) {
            if (info.mode == modeAccumulator) {
                auto c = this.c;
                this.c = this.a & 1;
                this.a = cast(ubyte)((this.a >> 1) | (c << 7));
                this.setZN(this.a);
            } else {
                auto c = this.c;
                auto value = this.memoryRead(info.address);
                this.memoryWrite(info.address, value); // dummy write
                this.c = value & 1;
                value = cast(ubyte)((value >> 1) | (c << 7));
                this.setZN(value);
                this.memoryWrite(info.address, value);
            }
        }

        // RTI - Return from Interrupt
        void rti(stepInfo* info) {
            this.memoryRead(this.pc); // dummy read
            this.setFlags((this.pull() & 0xCF) | 0x20);
            this.pc = this.pull16();
        }

        // RTS - Return from Subroutine
        void rts(stepInfo* info) {
            auto addr = cast(ushort)(this.pull16() + 1);
            this.memoryRead(this.pc); // dummy read
            this.memoryRead(this.pc); // dummy read
            this.pc = addr;
        }

        // SBC - Subtract with Carry
        void sbc(stepInfo* info) {
            auto a = this.a;
            auto b = this.memoryRead(info.address);
            auto c = this.c;
            this.a = cast(ubyte)(a - b - (1 - c));
            this.setZN(this.a);
            if (cast(int)a - cast(int)b - cast(int)(1 - c) >= 0) {
                this.c = 1;
            } else {
                this.c = 0;
            }
            if (((a ^ b) & 0x80) != 0 && ((a ^ this.a) & 0x80) != 0) {
                this.v = 1;
            } else {
                this.v = 0;
            }
        }

        // SEC - Set Carry Flag
        void sec(stepInfo* info) {
            this.c = 1;
        }

        // SED - Set Decimal Flag
        void sed(stepInfo* info) {
            this.d = 1;
        }

        // SEI - Set Interrupt Disable
        void sei(stepInfo* info) {
            this.i = 1;
        }

        // STA - Store Accumulator
        void sta(stepInfo* info) {
            this.memoryWrite(info.address, this.a);
        }

        // STX - Store X Register
        void stx(stepInfo* info) {
            this.memoryWrite(info.address, this.x);
        }

        // STY - Store Y Register
        void sty(stepInfo* info) {
            this.memoryWrite(info.address, this.y);
        }

        // TAX - Transfer Accumulator to X
        void tax(stepInfo* info) {
            this.x = this.a;
            this.setZN(this.x);
        }

        // TAY - Transfer Accumulator to Y
        void tay(stepInfo* info) {
            this.y = this.a;
            this.setZN(this.y);
        }

        // TSX - Transfer Stack Pointer to X
        void tsx(stepInfo* info) {
            this.x = this.sp;
            this.setZN(this.x);
        }

        // TXA - Transfer X to Accumulator
        void txa(stepInfo* info) {
            this.a = this.x;
            this.setZN(this.a);
        }

        // TXS - Transfer X to Stack Pointer
        void txs(stepInfo* info) {
            this.sp = this.x;
        }

        // TYA - Transfer Y to Accumulator
        void tya(stepInfo* info) {
            this.a = this.y;
            this.setZN(this.a);
        }

        // illegal opcodes below

        // AKA AXA
        void ahx(stepInfo* info) {
            this.memoryWrite(info.address,
                ((info.address >> 8) + 1) & this.a & this.x);
        }

        void aac(stepInfo* info) {
            // Not sure if this is correct
            auto value = this.memoryRead(info.address);
            this.a &= value;
            this.setZN(this.a);
            this.c = this.n;
        }

        void asr(stepInfo* info) {
            this.c = 0;
            auto value = this.memoryRead(info.address);
            this.a &= value;
            this.setZN(this.a);

            if (this.a & 0x01) this.c = 1;

            this.a >>= 1;
            this.setZN(this.a);
        }

        void arr(stepInfo* info) {
            // Not sure if this is correct
            auto value = this.memoryRead(info.address);

            this.a = ((this.a & value) >> 1) | (this.c ? 0x80 : 0x00);

            this.setZN(this.a);
            this.c = 0;
            this.v = 0;

            if (this.a & 0x40) this.c = 1;
            if ((this.c ? 0x01 : 0x00) ^ ((this.a >> 5) & 0x01))
                this.v = 1;
        }

        void atx(stepInfo* info) {
            // Not sure if this is correct
            auto value = this.memoryRead(info.address);
            this.a = value;
            this.x = this.a;
            this.setZN(this.a);

        }

        void axs(stepInfo* info) {
            // Not sure if this is correct
            auto orgValue = this.memoryRead(info.address);
            ubyte value = cast(ubyte)((this.a & this.x) - orgValue);

            this.c = 0;
            if ((this.a & this.x) >= orgValue) this.c = 1;

            this.x = value;
            this.setZN(this.x);
        }

        void dcp(stepInfo* info) {
            // Not sure if this is correct
            auto value = this.memoryRead(info.address);
            this.memoryWrite(info.address, value); // dummy write
            value--;
            this.compare(this.a, value);
            this.memoryWrite(info.address, value);
        }

        void isc(stepInfo* info) {
            // Not sure if this is correct
            auto value = this.memoryRead(info.address);
            this.memoryWrite(info.address, value); // dummy write
            value++;

            // SBC
            auto a = this.a;
            auto b = value;
            auto c = this.c;
            this.a = cast(ubyte)(a - b - (1 - c));
            this.setZN(this.a);
            if (cast(int)a - cast(int)b - cast(int)(1 - c) >= 0) {
                this.c = 1;
            } else {
                this.c = 0;
            }
            if (((a ^ b) & 0x80) != 0 && ((a ^ this.a) & 0x80) != 0) {
                this.v = 1;
            } else {
                this.v = 0;
            }

            this.memoryWrite(info.address, value);
        }

        void kil(stepInfo* info) {
        }

        // AKA LAR
        void las(stepInfo* info) {
            auto value = this.memoryRead(info.address);
            this.a = value & this.sp;
            this.x = this.a;
            this.setZN(this.x);
            this.sp = this.a;
        }

        void lax(stepInfo* info) {
            auto value = this.memoryRead(info.address);
            this.x = value;
            this.a = value;
            this.setZN(value);
        }

        void rla(stepInfo* info) {
            // Not sure if this is correct
            auto value = this.memoryRead(info.address);
            this.memoryWrite(info.address, value); // dummy write

            // ROL
            auto c = this.c;
            this.c = (value >> 7) & 1;
            value = cast(ubyte)((value << 1) | c);
            this.setZN(value);

            this.a &= value;
            this.setZN(this.a);

            this.memoryWrite(info.address, value);
        }

        void rra(stepInfo* info) {
            // Not sure if this is correct
            auto value = this.memoryRead(info.address);
            this.memoryWrite(info.address, value); // dummy write

            // ROR
            auto c = this.c;
            this.c = value & 1;
            value = cast(ubyte)((value >> 1) | (c << 7));
            this.setZN(value);

            // ADC
            auto a = this.a;
            auto b = value;
            c = this.c;
            this.a = cast(ubyte)(a + b + c);
            this.setZN(this.a);
            if (cast(int)a + cast(int)b + cast(int)c > 0xFF) {
                this.c = 1;
            } else {
                this.c = 0;
            }
            if (((a ^ b) & 0x80) == 0 && ((a ^ this.a) & 0x80) != 0) {
                this.v = 1;
            } else {
                this.v = 0;
            }

            this.memoryWrite(info.address, value);
        }

        // AKA AAX
        void sax(stepInfo* info) {
            // Not sure if this is correct
            this.memoryWrite(info.address, this.a & this.x);
        }

        // AKA SHX
        void sxa(stepInfo* info) {
            ubyte hi = info.address >> 8;
            ubyte lo = info.address & 0xFF;
            ubyte value = this.x & (hi + 1);
            this.memoryWrite(((this.x & (hi + 1)) << 8) | lo, value);
        }

        // AKA SHY
        void sya(stepInfo* info) {
            ubyte hi = info.address >> 8;
            ubyte lo = info.address & 0xFF;
            ubyte value = this.y & (hi + 1);
            
            this.memoryWrite(((this.y & (hi + 1)) << 8) | lo, value);
        }

        void slo(stepInfo* info) {
            // Not sure if this is correct
            auto value = this.memoryRead(info.address);
            this.memoryWrite(info.address, value); // dummy write

            // ASL
            this.c = (value >> 7) & 1;
            value <<= 1;
            this.setZN(value);

            // ORA
            this.a = this.a | value;
            this.setZN(this.a);

            this.memoryWrite(info.address, value);
        }

        void sre(stepInfo* info) {
            // Not sure if this is correct
            auto value = this.memoryRead(info.address);
            this.memoryWrite(info.address, value); // dummy write

            // LSR
            this.c = value & 1;
            value >>= 1;
            this.setZN(value);

            // EOR
            this.a = this.a ^ value;
            this.setZN(this.a);

            this.memoryWrite(info.address, value);
        }

        void tas(stepInfo* info) {
            this.sp = this.x & this.a;
            this.memoryWrite(info.address, this.sp & ((info.address >> 8) + 1));
        }

        void xaa(stepInfo* info) {
            this.memoryRead(this.pc); // dummy read
        }
}
