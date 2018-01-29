module nes.cpu;

import std.conv;
import std.format;
import std.stdio;

import nes.console;
import nes.memory;

enum CPUFrequency = 1789773;

// interrupt types
enum {
    interruptNone = 1,
    interruptNMI,
    interruptIRQ
}

// addressing modes
enum {
    modeAbsolute = 1,
    modeAbsoluteX,
    modeAbsoluteY,
    modeAccumulator,
    modeImmediate,
    modeImplied,
    modeIndexedIndirect,
    modeIndirect,
    modeIndirectIndexed,
    modeRelative,
    modeZeroPage,
    modeZeroPageX,
    modeZeroPageY
}

// instructionModes indicates the addressing mode for each instruction
ubyte[256] instructionModes = [
    6, 7, 6, 7, 11, 11, 11, 11, 6, 5, 4, 5, 1, 1, 1, 1,
    10, 9, 6, 9, 12, 12, 12, 12, 6, 3, 6, 3, 2, 2, 2, 2,
    1, 7, 6, 7, 11, 11, 11, 11, 6, 5, 4, 5, 1, 1, 1, 1,
    10, 9, 6, 9, 12, 12, 12, 12, 6, 3, 6, 3, 2, 2, 2, 2,
    6, 7, 6, 7, 11, 11, 11, 11, 6, 5, 4, 5, 1, 1, 1, 1,
    10, 9, 6, 9, 12, 12, 12, 12, 6, 3, 6, 3, 2, 2, 2, 2,
    6, 7, 6, 7, 11, 11, 11, 11, 6, 5, 4, 5, 8, 1, 1, 1,
    10, 9, 6, 9, 12, 12, 12, 12, 6, 3, 6, 3, 2, 2, 2, 2,
    5, 7, 5, 7, 11, 11, 11, 11, 6, 5, 6, 5, 1, 1, 1, 1,
    10, 9, 6, 9, 12, 12, 13, 13, 6, 3, 6, 3, 2, 2, 3, 3,
    5, 7, 5, 7, 11, 11, 11, 11, 6, 5, 6, 5, 1, 1, 1, 1,
    10, 9, 6, 9, 12, 12, 13, 13, 6, 3, 6, 3, 2, 2, 3, 3,
    5, 7, 5, 7, 11, 11, 11, 11, 6, 5, 6, 5, 1, 1, 1, 1,
    10, 9, 6, 9, 12, 12, 12, 12, 6, 3, 6, 3, 2, 2, 2, 2,
    5, 7, 5, 7, 11, 11, 11, 11, 6, 5, 6, 5, 1, 1, 1, 1,
    10, 9, 6, 9, 12, 12, 12, 12, 6, 3, 6, 3, 2, 2, 2, 2
];

// instructionSizes indicates the size of each instruction in bytes
ubyte[256] instructionSizes = [
    1, 2, 0, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
    2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0,
    3, 2, 0, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
    2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0,
    1, 2, 0, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
    2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0,
    1, 2, 0, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
    2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0,
    2, 2, 0, 0, 2, 2, 2, 0, 1, 0, 1, 0, 3, 3, 3, 0,
    2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 0, 3, 0, 0,
    2, 2, 2, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
    2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0,
    2, 2, 0, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
    2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0,
    2, 2, 0, 0, 2, 2, 2, 0, 1, 2, 1, 0, 3, 3, 3, 0,
    2, 2, 0, 0, 2, 2, 2, 0, 1, 3, 1, 0, 3, 3, 3, 0
];

// instructionCycles indicates the number of cycles used by each instruction,
// not including conditional cycles
ubyte[256] instructionCycles = [
    7, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 4, 4, 6, 6,
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 4, 4, 6, 6,
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    6, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 3, 4, 6, 6,
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 5, 4, 6, 6,
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
    2, 6, 2, 6, 4, 4, 4, 4, 2, 5, 2, 5, 5, 5, 5, 5,
    2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
    2, 5, 2, 5, 4, 4, 4, 4, 2, 4, 2, 4, 4, 4, 4, 4,
    2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
    2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
    2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7
];

// instructionPageCycles indicates the number of cycles used by each
// instruction when a page is crossed
ubyte[256] instructionPageCycles = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0
];

// instructionNames indicates the name of each instruction
string[256] instructionNames = [
    "BRK", "ORA", "KIL", "SLO", "NOP", "ORA", "ASL", "SLO",
    "PHP", "ORA", "ASL", "ANC", "NOP", "ORA", "ASL", "SLO",
    "BPL", "ORA", "KIL", "SLO", "NOP", "ORA", "ASL", "SLO",
    "CLC", "ORA", "NOP", "SLO", "NOP", "ORA", "ASL", "SLO",
    "JSR", "AND", "KIL", "RLA", "BIT", "AND", "ROL", "RLA",
    "PLP", "AND", "ROL", "ANC", "BIT", "AND", "ROL", "RLA",
    "BMI", "AND", "KIL", "RLA", "NOP", "AND", "ROL", "RLA",
    "SEC", "AND", "NOP", "RLA", "NOP", "AND", "ROL", "RLA",
    "RTI", "EOR", "KIL", "SRE", "NOP", "EOR", "LSR", "SRE",
    "PHA", "EOR", "LSR", "ALR", "JMP", "EOR", "LSR", "SRE",
    "BVC", "EOR", "KIL", "SRE", "NOP", "EOR", "LSR", "SRE",
    "CLI", "EOR", "NOP", "SRE", "NOP", "EOR", "LSR", "SRE",
    "RTS", "ADC", "KIL", "RRA", "NOP", "ADC", "ROR", "RRA",
    "PLA", "ADC", "ROR", "ARR", "JMP", "ADC", "ROR", "RRA",
    "BVS", "ADC", "KIL", "RRA", "NOP", "ADC", "ROR", "RRA",
    "SEI", "ADC", "NOP", "RRA", "NOP", "ADC", "ROR", "RRA",
    "NOP", "STA", "NOP", "SAX", "STY", "STA", "STX", "SAX",
    "DEY", "NOP", "TXA", "XAA", "STY", "STA", "STX", "SAX",
    "BCC", "STA", "KIL", "AHX", "STY", "STA", "STX", "SAX",
    "TYA", "STA", "TXS", "TAS", "SHY", "STA", "SHX", "AHX",
    "LDY", "LDA", "LDX", "LAX", "LDY", "LDA", "LDX", "LAX",
    "TAY", "LDA", "TAX", "LAX", "LDY", "LDA", "LDX", "LAX",
    "BCS", "LDA", "KIL", "LAX", "LDY", "LDA", "LDX", "LAX",
    "CLV", "LDA", "TSX", "LAS", "LDY", "LDA", "LDX", "LAX",
    "CPY", "CMP", "NOP", "DCP", "CPY", "CMP", "DEC", "DCP",
    "INY", "CMP", "DEX", "AXS", "CPY", "CMP", "DEC", "DCP",
    "BNE", "CMP", "KIL", "DCP", "NOP", "CMP", "DEC", "DCP",
    "CLD", "CMP", "NOP", "DCP", "NOP", "CMP", "DEC", "DCP",
    "CPX", "SBC", "NOP", "ISC", "CPX", "SBC", "INC", "ISC",
    "INX", "SBC", "NOP", "SBC", "CPX", "SBC", "INC", "ISC",
    "BEQ", "SBC", "KIL", "ISC", "NOP", "SBC", "INC", "ISC",
    "SED", "SBC", "NOP", "ISC", "NOP", "SBC", "INC", "ISC"
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
    ubyte a ;     // accumulator
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
    int step() {
        if (this.stall > 0) {
            this.stall--;
            return 1;
        }

        auto cycles = this.cycles;

        switch (this.interrupt) {
            case interruptNMI:
                this.nmi();
                break;
            case interruptIRQ:
                this.irq();
                break;
            default:
                break;
        }
        this.interrupt = interruptNone;

        auto opcode = this.read(this.pc);
        auto mode = instructionModes[opcode];

        ushort address;
        bool pageCrossed;
        switch (mode) {
            case modeAbsolute:
                address = this.read16(cast(ushort)(this.pc + 1));
                break;
            case modeAbsoluteX:
                address = cast(ushort)(this.read16(cast(ushort)(this.pc + 1)) + this.x);
                pageCrossed = pagesDiffer(cast(ushort)(address - this.x), address);
                break;
            case modeAbsoluteY:
                address = cast(ushort)(this.read16(cast(ushort)(this.pc + 1)) + this.y);
                pageCrossed = pagesDiffer(cast(ushort)(address - this.y), address);
                break;
            case modeAccumulator:
                address = 0;
                break;
            case modeImmediate:
                address = cast(ushort)(this.pc + 1);
                break;
            case modeImplied:
                address = 0;
                break;
            case modeIndexedIndirect:
                address = this.read16bug(cast(ushort)(this.read(cast(ushort)(this.pc + 1)) + this.x));
                break;
            case modeIndirect:
                address = this.read16bug(this.read16(cast(ushort)(this.pc + 1)));
                break;
            case modeIndirectIndexed:
                address = cast(ushort)(this.read16bug(this.read(cast(ushort)(this.pc + 1))) + this.y);
                pageCrossed = pagesDiffer(cast(ushort)(address - this.y), address);
                break;
            case modeRelative:
                auto offset = cast(ushort)this.read(cast(ushort)(this.pc + 1));
                if (offset < 0x80) {
                    address = cast(ushort)(this.pc + 2 + offset);
                } else {
                    address = cast(ushort)(this.pc + 2 + offset - 0x100);
                }
                break;
            case modeZeroPage:
                address = cast(ushort)this.read(cast(ushort)(this.pc + 1));
                break;
            case modeZeroPageX:
                address = cast(ushort)(this.read(cast(ushort)(this.pc + 1)) + this.x) & 0xff;
                break;
            case modeZeroPageY:
                address = cast(ushort)(this.read(cast(ushort)(this.pc + 1)) + this.y) & 0xff;
                break;
            default:
                break;
        }

        this.pc += cast(ushort)instructionSizes[opcode];
        this.cycles += cast(ulong)instructionCycles[opcode];
        if (pageCrossed) {
            this.cycles += cast(ulong)instructionPageCycles[opcode];
        }
        auto info = stepInfo(address, this.pc, mode);
        this.table[opcode](&info);

        return cast(int)(this.cycles - cycles);
    }

    // triggerNMI causes a non-maskable interrupt to occur on the next cycle
    void triggerNMI() {
        this.interrupt = interruptNMI;
    }

    // triggerIRQ causes an IRQ interrupt to occur on the next cycle
    void triggerIRQ() {
        if (this.i == 0) {
            this.interrupt = interruptIRQ;
        }
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
        state["cpu.interrupt"] = to!string(this.interrupt);
        state["cpu.stall"] = to!string(this.stall);
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
        this.interrupt = to!ubyte(state["cpu.interrupt"]);
        this.stall = to!int(state["cpu.stall"]);
    }

    private:
        ubyte interrupt; // interrupt type to perform
        InstructionFuncType[256] table;

        // createTable builds a function table for each instruction
        void createTable() {
            this.table = [
                &this.brk, &this.ora, &this.kil, &this.slo, &this.nop, &this.ora, &this.asl, &this.slo,
                &this.php, &this.ora, &this.asl, &this.anc, &this.nop, &this.ora, &this.asl, &this.slo,
                &this.bpl, &this.ora, &this.kil, &this.slo, &this.nop, &this.ora, &this.asl, &this.slo,
                &this.clc, &this.ora, &this.nop, &this.slo, &this.nop, &this.ora, &this.asl, &this.slo,
                &this.jsr, &this.and, &this.kil, &this.rla, &this.bit, &this.and, &this.rol, &this.rla,
                &this.plp, &this.and, &this.rol, &this.anc, &this.bit, &this.and, &this.rol, &this.rla,
                &this.bmi, &this.and, &this.kil, &this.rla, &this.nop, &this.and, &this.rol, &this.rla,
                &this.sec, &this.and, &this.nop, &this.rla, &this.nop, &this.and, &this.rol, &this.rla,
                &this.rti, &this.eor, &this.kil, &this.sre, &this.nop, &this.eor, &this.lsr, &this.sre,
                &this.pha, &this.eor, &this.lsr, &this.alr, &this.jmp, &this.eor, &this.lsr, &this.sre,
                &this.bvc, &this.eor, &this.kil, &this.sre, &this.nop, &this.eor, &this.lsr, &this.sre,
                &this.cli, &this.eor, &this.nop, &this.sre, &this.nop, &this.eor, &this.lsr, &this.sre,
                &this.rts, &this.adc, &this.kil, &this.rra, &this.nop, &this.adc, &this.ror, &this.rra,
                &this.pla, &this.adc, &this.ror, &this.arr, &this.jmp, &this.adc, &this.ror, &this.rra,
                &this.bvs, &this.adc, &this.kil, &this.rra, &this.nop, &this.adc, &this.ror, &this.rra,
                &this.sei, &this.adc, &this.nop, &this.rra, &this.nop, &this.adc, &this.ror, &this.rra,
                &this.nop, &this.sta, &this.nop, &this.sax, &this.sty, &this.sta, &this.stx, &this.sax,
                &this.dey, &this.nop, &this.txa, &this.xaa, &this.sty, &this.sta, &this.stx, &this.sax,
                &this.bcc, &this.sta, &this.kil, &this.ahx, &this.sty, &this.sta, &this.stx, &this.sax,
                &this.tya, &this.sta, &this.txs, &this.tas, &this.shy, &this.sta, &this.shx, &this.ahx,
                &this.ldy, &this.lda, &this.ldx, &this.lax, &this.ldy, &this.lda, &this.ldx, &this.lax,
                &this.tay, &this.lda, &this.tax, &this.lax, &this.ldy, &this.lda, &this.ldx, &this.lax,
                &this.bcs, &this.lda, &this.kil, &this.lax, &this.ldy, &this.lda, &this.ldx, &this.lax,
                &this.clv, &this.lda, &this.tsx, &this.las, &this.ldy, &this.lda, &this.ldx, &this.lax,
                &this.cpy, &this.cmp, &this.nop, &this.dcp, &this.cpy, &this.cmp, &this.dec, &this.dcp,
                &this.iny, &this.cmp, &this.dex, &this.axs, &this.cpy, &this.cmp, &this.dec, &this.dcp,
                &this.bne, &this.cmp, &this.kil, &this.dcp, &this.nop, &this.cmp, &this.dec, &this.dcp,
                &this.cld, &this.cmp, &this.nop, &this.dcp, &this.nop, &this.cmp, &this.dec, &this.dcp,
                &this.cpx, &this.sbc, &this.nop, &this.isc, &this.cpx, &this.sbc, &this.inc, &this.isc,
                &this.inx, &this.sbc, &this.nop, &this.sbc, &this.cpx, &this.sbc, &this.inc, &this.isc,
                &this.beq, &this.sbc, &this.kil, &this.isc, &this.nop, &this.sbc, &this.inc, &this.isc,
                &this.sed, &this.sbc, &this.nop, &this.isc, &this.nop, &this.sbc, &this.inc, &this.isc
            ];
        }

        // addBranchCycles adds a cycle for taking a branch and adds another cycle
        // if the branch jumps to a new page
        void addBranchCycles(stepInfo* info) {
            this.cycles++;
            if (pagesDiffer(info.pc, info.address)) {
                this.cycles++;
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

        // read16bug emulates a 6502 bug that caused the low byte to wrap without
        // incrementing the high byte
        ushort read16bug(ushort address) {
            auto a = address;
            ushort b = (a & 0xFF00) | cast(ushort)(cast(ubyte)a + 1);
            auto lo = this.read(a);
            auto hi = this.read(b);
            return cast(ushort)hi << 8 | cast(ushort)lo;
        }

        // push pushes a byte onto the stack
        void push(ubyte value) {
            this.write(0x100 | cast(ushort)this.sp, value);
            this.sp--;
        }

        // pull pops a byte from the stack
        ubyte pull() {
            this.sp++;
            return this.read(0x100 | cast(ushort)this.sp);
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
            this.push16(this.pc);
            this.php(null);
            this.pc = this.read16(0xFFFA);
            this.i = 1;
            this.cycles += 7;
        }

        // IRQ - IRQ Interrupt
        void irq() {
            this.push16(this.pc);
            this.php(null);
            this.pc = this.read16(0xFFFE);
            this.i = 1;
            this.cycles += 7;
        }

        // ADC - Add with Carry
        void adc(stepInfo* info) {
            auto a = this.a;
            auto b = this.read(info.address);
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
            this.a = this.a & this.read(info.address);
            this.setZN(this.a);
        }

        // ASL - Arithmetic Shift Left
        void asl(stepInfo* info) {
            if (info.mode == modeAccumulator) {
                this.c = (this.a >> 7) & 1;
                this.a <<= 1;
                this.setZN(this.a);
            } else {
                auto value = this.read(info.address);
                this.c = (value >> 7) & 1;
                value <<= 1;
                this.write(info.address, value);
                this.setZN(value);
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
            auto value = this.read(info.address);
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
            this.push16(this.pc);
            this.php(info);
            this.sei(info);
            this.pc = this.read16(0xFFFE);
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
            auto value = this.read(info.address);
            this.compare(this.a, value);
        }

        // CPX - Compare X Register
        void cpx(stepInfo* info) {
            auto value = this.read(info.address);
            this.compare(this.x, value);
        }

        // CPY - Compare Y Register
        void cpy(stepInfo* info) {
            auto value = this.read(info.address);
            this.compare(this.y, value);
        }

        // DEC - Decrement Memory
        void dec(stepInfo* info) {
            auto value = cast(ubyte)(this.read(info.address) - 1);
            this.write(info.address, value);
            this.setZN(value);
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
            this.a = this.a ^ this.read(info.address);
            this.setZN(this.a);
        }

        // INC - Increment Memory
        void inc(stepInfo* info) {
            auto value = cast(ubyte)(this.read(info.address) + 1);
            this.write(info.address, value);
            this.setZN(value);
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
            this.push16(cast(ushort)(this.pc - 1));
            this.pc = info.address;
        }

        // LDA - Load Accumulator
        void lda(stepInfo* info) {
            this.a = this.read(info.address);
            this.setZN(this.a);
        }

        // LDX - Load X Register
        void ldx(stepInfo* info) {
            this.x = this.read(info.address);
            this.setZN(this.x);
        }

        // LDY - Load Y Register
        void ldy(stepInfo* info) {
            this.y = this.read(info.address);
            this.setZN(this.y);
        }

        // LSR - Logical Shift Right
        void lsr(stepInfo* info) {
            if (info.mode == modeAccumulator) {
                this.c = this.a & 1;
                this.a >>= 1;
                this.setZN(this.a);
            } else {
                auto value = this.read(info.address);
                this.c = value & 1;
                value >>= 1;
                this.write(info.address, value);
                this.setZN(value);
            }
        }

        // NOP - No Operation
        void nop(stepInfo* info) {
        }

        // ORA - Logical Inclusive OR
        void ora(stepInfo* info) {
            this.a = this.a | this.read(info.address);
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
            this.a = this.pull();
            this.setZN(this.a);
        }

        // PLP - Pull Processor Status
        void plp(stepInfo* info) {
            this.setFlags(this.pull() & 0xEF | 0x20);
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
                auto value = this.read(info.address);
                this.c = (value >> 7) & 1;
                value = cast(ubyte)((value << 1) | c);
                this.write(info.address, value);
                this.setZN(value);
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
                auto value = this.read(info.address);
                this.c = value & 1;
                value = cast(ubyte)((value >> 1) | (c << 7));
                this.write(info.address, value);
                this.setZN(value);
            }
        }

        // RTI - Return from Interrupt
        void rti(stepInfo* info) {
            this.setFlags(this.pull() & 0xEF | 0x20);
            this.pc = this.pull16();
        }

        // RTS - Return from Subroutine
        void rts(stepInfo* info) {
            this.pc = cast(ushort)(this.pull16() + 1);
        }

        // SBC - Subtract with Carry
        void sbc(stepInfo* info) {
            auto a = this.a;
            auto b = this.read(info.address);
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
            this.write(info.address, this.a);
        }

        // STX - Store X Register
        void stx(stepInfo* info) {
            this.write(info.address, this.x);
        }

        // STY - Store Y Register
        void sty(stepInfo* info) {
            this.write(info.address, this.y);
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

        void ahx(stepInfo* info) {
        }

        void alr(stepInfo* info) {
        }

        void anc(stepInfo* info) {
        }

        void arr(stepInfo* info) {
        }

        void axs(stepInfo* info) {
        }

        void dcp(stepInfo* info) {
        }

        void isc(stepInfo* info) {
        }

        void kil(stepInfo* info) {
        }

        void las(stepInfo* info) {
        }

        void lax(stepInfo* info) {
        }

        void rla(stepInfo* info) {
        }

        void rra(stepInfo* info) {
        }

        void sax(stepInfo* info) {
        }

        void shx(stepInfo* info) {
        }

        void shy(stepInfo* info) {
        }

        void slo(stepInfo* info) {
        }

        void sre(stepInfo* info) {
        }

        void tas(stepInfo* info) {
        }

        void xaa(stepInfo* info) {
        }
}
