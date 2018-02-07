module nes.apu;

import std.conv;
import std.stdio;

import nes.console;
import nes.cpu;
import nes.filter;

enum frameCounterRate = CPUFrequency / 240.0;

ubyte[] lengthTable = [
    10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14,
    12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30
];

ubyte[][] dutyTable = [
    [0, 1, 0, 0, 0, 0, 0, 0],
    [0, 1, 1, 0, 0, 0, 0, 0],
    [0, 1, 1, 1, 1, 0, 0, 0],
    [1, 0, 0, 1, 1, 1, 1, 1]
];

ubyte[] triangleTable = [
    15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
];

ushort[] noiseTable = [
    4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068
];

ubyte[] dmcTable = [
    214, 190, 170, 160, 143, 127, 113, 107, 95, 80, 71, 64, 53, 42, 36, 27
];

float[31] pulseTable;
float[203] tndTable;

static this() {
    foreach (i; 0 .. 31) {
        pulseTable[i] = 95.52 / (8128.0 / cast(float)i + 100);
    }
    foreach (i; 0 .. 203) {
        tndTable[i] = 163.67 / (24329.0 / cast(float)i + 100);
    }
}

alias void delegate(float) ApuCallbackFuncType;

class APU {
    this(Console console) {
        this.console = console;
        this.noise.shiftRegister = 1;
        this.pulse1.channel = 1;
        this.pulse2.channel = 2;
        this.dmc.cpu = console.cpu;
    }

    void step() {
        auto cycle1 = this.cycle;
        this.cycle++;
        auto cycle2 = this.cycle;
        this.stepTimer();
        auto f1 = cast(int)(cast(double)cycle1 / frameCounterRate);
        auto f2 = cast(int)(cast(double)cycle2 / frameCounterRate);
        if (f1 != f2) {
            this.stepFrameCounter();
        }
        auto s1 = cast(int)(cast(double)cycle1 / this.sampleRate);
        auto s2 = cast(int)(cast(double)cycle2 / this.sampleRate);
        if (s1 != s2) {
            this.sendSample();
        }
    }

    ubyte readRegister(ushort address) {
        switch (address) {
            case 0x4015:
                return this.readStatus();
            default:
                break;
            // default:
            //     log.Fatalf("unhandled apu register read at address: 0x%04X", address)
        }
        return 0;
    }

    void writeRegister(ushort address, ubyte value) {
        switch (address) {
            case 0x4000:
                this.pulse1.writeControl(value);
                break;
            case 0x4001:
                this.pulse1.writeSweep(value);
                break;
            case 0x4002:
                this.pulse1.writeTimerLow(value);
                break;
            case 0x4003:
                this.pulse1.writeTimerHigh(value);
                break;
            case 0x4004:
                this.pulse2.writeControl(value);
                break;
            case 0x4005:
                this.pulse2.writeSweep(value);
                break;
            case 0x4006:
                this.pulse2.writeTimerLow(value);
                break;
            case 0x4007:
                this.pulse2.writeTimerHigh(value);
                break;
            case 0x4008:
                this.triangle.writeControl(value);
                break;
            case 0x4009:
                break;
            case 0x4010:
                this.dmc.writeControl(value);
                break;
            case 0x4011:
                this.dmc.writeValue(value);
                break;
            case 0x4012:
                this.dmc.writeAddress(value);
                break;
            case 0x4013:
                this.dmc.writeLength(value);
                break;
            case 0x400A:
                this.triangle.writeTimerLow(value);
                break;
            case 0x400B:
                this.triangle.writeTimerHigh(value);
                break;
            case 0x400C:
                this.noise.writeControl(value);
                break;
            case 0x400D:
                break;
            case 0x400E:
                this.noise.writePeriod(value);
                break;
            case 0x400F:
                this.noise.writeLength(value);
                break;
            case 0x4015:
                this.writeControl(value);
                break;
            case 0x4017:
                this.writeFrameCounter(value);
                break;
            default:
                break;
            // default:
            //     log.Fatalf("unhandled apu register write at address: 0x%04X", address)
        }
    }

    void save(string[string] state) {
        state["apu.cycle"] = to!string(this.cycle);
        state["apu.framePeriod"] = to!string(this.framePeriod);
        state["apu.frameValue"] = to!string(this.frameValue);
        state["apu.frameIRQ"] = to!string(this.frameIRQ);

        this.pulse1.save(state, "1");
        this.pulse2.save(state, "2");
        this.triangle.save(state);
        this.noise.save(state);
        this.dmc.save(state);
    }

    void load(string[string] state) {
        this.cycle = to!ulong(state["apu.cycle"]);
        this.framePeriod = to!ubyte(state["apu.framePeriod"]);
        this.frameValue = to!ubyte(state["apu.frameValue"]);
        this.frameIRQ = to!bool(state["apu.frameIRQ"]);

        this.pulse1.load(state, "1");
        this.pulse2.load(state, "2");
        this.triangle.load(state);
        this.noise.load(state);
        this.dmc.load(state);
    }

    package:
        double              sampleRate;
        ApuCallbackFuncType callback;
        FilterChain         filterChain;

        Console console;
        Pulse pulse1;
        Pulse pulse2;
        Triangle triangle;
        Noise noise;
        DMC dmc;
        ulong cycle;
        ubyte framePeriod;
        ubyte frameValue;
        bool frameIRQ;

    private:
        void sendSample() {
            auto output = this.filterChain.step(this.output());
            if (this.callback)
                this.callback(output);
        }

        float output() {
            auto p1 = this.pulse1.output();
            auto p2 = this.pulse2.output();
            auto t = this.triangle.output();
            auto n = this.noise.output();
            auto d = this.dmc.output();
            auto pulseOut = pulseTable[p1 + p2];
            auto tndOut = tndTable[3 * t + 2 * n + d];

            return pulseOut + tndOut;
        }

        // mode 0:    mode 1:       function
        // ---------  -----------  -----------------------------
        //  - - - f    - - - - -    IRQ (if bit 6 is clear)
        //  - l - l    l - l - -    Length counter and sweep
        //  e e e e    e e e e -    Envelope and linear counter
        void stepFrameCounter() {
            switch (this.framePeriod) {
                case 4:
                    this.frameValue = (this.frameValue + 1) % 4;
                    switch (this.frameValue) {
                        case 0, 2:
                            this.stepEnvelope();
                            break;
                        case 1:
                            this.stepEnvelope();
                            this.stepSweep();
                            this.stepLength();
                            break;
                        case 3:
                            this.stepEnvelope();
                            this.stepSweep();
                            this.stepLength();
                            this.fireIRQ();
                            break;
                        default:
                            break;
                    }

                    break;
                case 5:
                    this.frameValue = (this.frameValue + 1) % 5;
                    switch (this.frameValue) {
                        case 1, 3:
                            this.stepEnvelope();
                            break;
                        case 0, 2:
                            this.stepEnvelope();
                            this.stepSweep();
                            this.stepLength();
                            break;
                        default:
                            break;
                    }

                    break;

                default:
                    break;
            }
        }

        void stepTimer() {
            if (this.cycle % 2 == 0) {
                this.pulse1.stepTimer();
                this.pulse2.stepTimer();
                this.noise.stepTimer();
                this.dmc.stepTimer();
            }
            this.triangle.stepTimer();
        }

        void stepEnvelope() {
            this.pulse1.stepEnvelope();
            this.pulse2.stepEnvelope();
            this.triangle.stepCounter();
            this.noise.stepEnvelope();
        }

        void stepSweep() {
            this.pulse1.stepSweep();
            this.pulse2.stepSweep();
        }

        void stepLength() {
            this.pulse1.stepLength();
            this.pulse2.stepLength();
            this.triangle.stepLength();
            this.noise.stepLength();
        }

        void fireIRQ() {
            if (this.frameIRQ) {
                this.console.cpu.triggerIRQ();
            }
        }

        ubyte readStatus() {
            ubyte result;
            if (this.pulse1.lengthValue > 0) {
                result |= 1;
            }
            if (this.pulse2.lengthValue > 0) {
                result |= 2;
            }
            if (this.triangle.lengthValue > 0) {
                result |= 4;
            }
            if (this.noise.lengthValue > 0) {
                result |= 8;
            }
            if (this.dmc.currentLength > 0) {
                result |= 16;
            }
            return result;
        }

        void writeControl(ubyte value) {
            this.pulse1.enabled = (value & 1) == 1;
            this.pulse2.enabled = (value & 2) == 2;
            this.triangle.enabled = (value & 4) == 4;
            this.noise.enabled = (value & 8) == 8;
            this.dmc.enabled = (value & 16) == 16;
            if (!this.pulse1.enabled) {
                this.pulse1.lengthValue = 0;
            }
            if (!this.pulse2.enabled) {
                this.pulse2.lengthValue = 0;
            }
            if (!this.triangle.enabled) {
                this.triangle.lengthValue = 0;
            }
            if (!this.noise.enabled) {
                this.noise.lengthValue = 0;
            }
            if (!this.dmc.enabled) {
                this.dmc.currentLength = 0;
            } else {
                if (this.dmc.currentLength == 0) {
                    this.dmc.restart();
                }
            }
        }

        void writeFrameCounter(ubyte value) {
            this.framePeriod = 4 + ((value >> 7) & 1);
            this.frameIRQ = ((value >> 6) & 1) == 0;
            // this.frameValue = 0;
            if (this.framePeriod == 5) {
                this.stepEnvelope();
                this.stepSweep();
                this.stepLength();
            }
        }
}

// Pulse

struct Pulse {
    bool   enabled;
    ubyte  channel;
    bool   lengthEnabled;
    ubyte  lengthValue;
    ushort timerPeriod;
    ushort timerValue;
    ubyte  dutyMode;
    ubyte  dutyValue;
    bool   sweepReload;
    bool   sweepEnabled;
    bool   sweepNegate;
    ubyte  sweepShift;
    ubyte  sweepPeriod;
    ubyte  sweepValue;
    bool   envelopeEnabled;
    bool   envelopeLoop;
    bool   envelopeStart;
    ubyte  envelopePeriod;
    ubyte  envelopeValue;
    ubyte  envelopeVolume;
    ubyte  constantVolume;

    void writeControl(ubyte value) {
        this.dutyMode = (value >> 6) & 3;
        this.lengthEnabled = ((value >> 5) & 1) == 0;
        this.envelopeLoop = ((value >> 5) & 1) == 1;
        this.envelopeEnabled = ((value >> 4) & 1) == 0;
        this.envelopePeriod = value & 15;
        this.constantVolume = value & 15;
        this.envelopeStart = true;
    }

    void writeSweep(ubyte value) {
        this.sweepEnabled = ((value >> 7) & 1) == 1;
        this.sweepPeriod = ((value >> 4) & 7) + 1;
        this.sweepNegate = ((value >> 3) & 1) == 1;
        this.sweepShift = value & 7;
        this.sweepReload = true;
    }

    void writeTimerLow(ubyte value) {
        this.timerPeriod = (this.timerPeriod & 0xFF00) | cast(ushort)value;
    }

    void writeTimerHigh(ubyte value) {
        this.lengthValue = lengthTable[value >> 3];
        this.timerPeriod = (this.timerPeriod & 0x00FF) | (cast(ushort)(value & 7) << 8);
        this.envelopeStart = true;
        this.dutyValue = 0;
    }

    void stepTimer() {
        if (this.timerValue == 0) {
            this.timerValue = this.timerPeriod;
            this.dutyValue = (this.dutyValue + 1) % 8;
        } else {
            this.timerValue--;
        }
    }

    void stepEnvelope() {
        if (this.envelopeStart) {
            this.envelopeVolume = 15;
            this.envelopeValue = this.envelopePeriod;
            this.envelopeStart = false;
        } else if (this.envelopeValue > 0) {
            this.envelopeValue--;
        } else {
            if (this.envelopeVolume > 0) {
                this.envelopeVolume--;
            } else if (this.envelopeLoop) {
                this.envelopeVolume = 15;
            }
            this.envelopeValue = this.envelopePeriod;
        }
    }

    void stepSweep() {
        if (this.sweepReload) {
            if (this.sweepEnabled && this.sweepValue == 0) {
                this.sweep();
            }
            this.sweepValue = this.sweepPeriod;
            this.sweepReload = false;
        } else if (this.sweepValue > 0) {
            this.sweepValue--;
        } else {
            if (this.sweepEnabled) {
                this.sweep();
            }
            this.sweepValue = this.sweepPeriod;
        }
    }

    void stepLength() {
        if (this.lengthEnabled && this.lengthValue > 0) {
            this.lengthValue--;
        }
    }

    void sweep() {
        auto delta = this.timerPeriod >> this.sweepShift;
        if (this.sweepNegate) {
            this.timerPeriod -= delta;
            if (this.channel == 1) {
                this.timerPeriod--;
            }
        } else {
            this.timerPeriod += delta;
        }
    }

    ubyte output() {
        if (!this.enabled) {
            return 0;
        }
        if (this.lengthValue == 0) {
            return 0;
        }
        if (dutyTable[this.dutyMode][this.dutyValue] == 0) {
            return 0;
        }
        if (this.timerPeriod < 8 || this.timerPeriod > 0x7FF) {
            return 0;
        }
        // if (!this.sweepNegate && this.timerPeriod + (this.timerPeriod >> this.sweepShift) > 0x7FF) {
        //  return 0;
        // }
        if (this.envelopeEnabled) {
            return this.envelopeVolume;
        } else {
            return this.constantVolume;
        }
    }

    void save(string[string] state, string id) {
        id = "apu.pulse" ~ id;

        state[id ~ ".enabled"] = to!string(this.enabled);
        state[id ~ ".channel"] = to!string(this.channel);
        state[id ~ ".lengthEnabled"] = to!string(this.lengthEnabled);
        state[id ~ ".lengthValue"] = to!string(this.lengthValue);
        state[id ~ ".timerPeriod"] = to!string(this.timerPeriod);
        state[id ~ ".timerValue"] = to!string(this.timerValue);
        state[id ~ ".dutyMode"] = to!string(this.dutyMode);
        state[id ~ ".dutyValue"] = to!string(this.dutyValue);
        state[id ~ ".sweepReload"] = to!string(this.sweepReload);
        state[id ~ ".sweepEnabled"] = to!string(this.sweepEnabled);
        state[id ~ ".sweepNegate"] = to!string(this.sweepNegate);
        state[id ~ ".sweepShift"] = to!string(this.sweepShift);
        state[id ~ ".sweepPeriod"] = to!string(this.sweepPeriod);
        state[id ~ ".sweepValue"] = to!string(this.sweepValue);
        state[id ~ ".envelopeEnabled"] = to!string(this.envelopeEnabled);
        state[id ~ ".envelopeLoop"] = to!string(this.envelopeLoop);
        state[id ~ ".envelopeStart"] = to!string(this.envelopeStart);
        state[id ~ ".envelopePeriod"] = to!string(this.envelopePeriod);
        state[id ~ ".envelopeValue"] = to!string(this.envelopeValue);
        state[id ~ ".envelopeVolume"] = to!string(this.envelopeVolume);
        state[id ~ ".constantVolume"] = to!string(this.constantVolume);
    }

    void load(string[string] state, string id) {
        id = "apu.pulse" ~ id;

        this.enabled = to!bool(state[id ~ ".enabled"]);
        this.channel = to!ubyte(state[id ~ ".channel"]);
        this.lengthEnabled = to!bool(state[id ~ ".lengthEnabled"]);
        this.lengthValue = to!ubyte(state[id ~ ".lengthValue"]);
        this.timerPeriod = to!ushort(state[id ~ ".timerPeriod"]);
        this.timerValue = to!ushort(state[id ~ ".timerValue"]);
        this.dutyMode = to!ubyte(state[id ~ ".dutyMode"]);
        this.dutyValue = to!ubyte(state[id ~ ".dutyValue"]);
        this.sweepReload = to!bool(state[id ~ ".sweepReload"]);
        this.sweepEnabled = to!bool(state[id ~ ".sweepEnabled"]);
        this.sweepNegate = to!bool(state[id ~ ".sweepNegate"]);
        this.sweepShift = to!ubyte(state[id ~ ".sweepShift"]);
        this.sweepPeriod = to!ubyte(state[id ~ ".sweepPeriod"]);
        this.sweepValue = to!ubyte(state[id ~ ".sweepValue"]);
        this.envelopeEnabled = to!bool(state[id ~ ".envelopeEnabled"]);
        this.envelopeLoop = to!bool(state[id ~ ".envelopeLoop"]);
        this.envelopeStart = to!bool(state[id ~ ".envelopeStart"]);
        this.envelopePeriod = to!ubyte(state[id ~ ".envelopePeriod"]);
        this.envelopeValue = to!ubyte(state[id ~ ".envelopeValue"]);
        this.envelopeVolume = to!ubyte(state[id ~ ".envelopeVolume"]);
        this.constantVolume = to!ubyte(state[id ~ ".constantVolume"]);
    }
}

// Triangle

struct Triangle {
    bool   enabled;
    bool   lengthEnabled;
    ubyte  lengthValue;
    ushort timerPeriod;
    ushort timerValue;
    ubyte  dutyValue;
    ubyte  counterPeriod;
    ubyte  counterValue;
    bool   counterReload;

    void writeControl(ubyte value) {
        this.lengthEnabled = ((value >> 7) & 1) == 0;
        this.counterPeriod = value & 0x7F;
    }

    void writeTimerLow(ubyte value) {
        this.timerPeriod = (this.timerPeriod & 0xFF00) | cast(ushort)value;
    }

    void writeTimerHigh(ubyte value) {
        this.lengthValue = lengthTable[value >> 3];
        this.timerPeriod = (this.timerPeriod & 0x00FF) | (cast(ushort)(value & 7) << 8);
        this.timerValue = this.timerPeriod;
        this.counterReload = true;
    }

    void stepTimer() {
        if (this.timerValue == 0) {
            this.timerValue = this.timerPeriod;
            if (this.lengthValue > 0 && this.counterValue > 0) {
                this.dutyValue = (this.dutyValue + 1) % 32;
            }
        } else {
            this.timerValue--;
        }
    }

    void stepLength() {
        if (this.lengthEnabled && this.lengthValue > 0) {
            this.lengthValue--;
        }
    }

    void stepCounter() {
        if (this.counterReload) {
            this.counterValue = this.counterPeriod;
        } else if (this.counterValue > 0) {
            this.counterValue--;
        }
        if (this.lengthEnabled) {
            this.counterReload = false;
        }
    }

    ubyte output() {
        if (!this.enabled) {
            return 0;
        }
        if (this.lengthValue == 0) {
            return 0;
        }
        if (this.counterValue == 0) {
            return 0;
        }
        return triangleTable[this.dutyValue];
    }

    void save(string[string] state) {
        state["apu.triangle.enabled"] = to!string(this.enabled);
        state["apu.triangle.lengthEnabled"] = to!string(this.lengthEnabled);
        state["apu.triangle.lengthValue"] = to!string(this.lengthValue);
        state["apu.triangle.timerPeriod"] = to!string(this.timerPeriod);
        state["apu.triangle.timerValue"] = to!string(this.timerValue);
        state["apu.triangle.dutyValue"] = to!string(this.dutyValue);
        state["apu.triangle.counterPeriod"] = to!string(this.counterPeriod);
        state["apu.triangle.counterValue"] = to!string(this.counterValue);
        state["apu.triangle.counterReload"] = to!string(this.counterReload);
    }

    void load(string[string] state) {
        this.enabled = to!bool(state["apu.triangle.enabled"]);
        this.lengthEnabled = to!bool(state["apu.triangle.lengthEnabled"]);
        this.lengthValue = to!ubyte(state["apu.triangle.lengthValue"]);
        this.timerPeriod = to!ushort(state["apu.triangle.timerPeriod"]);
        this.timerValue = to!ushort(state["apu.triangle.timerValue"]);
        this.dutyValue = to!ubyte(state["apu.triangle.dutyValue"]);
        this.counterPeriod = to!ubyte(state["apu.triangle.counterPeriod"]);
        this.counterValue = to!ubyte(state["apu.triangle.counterValue"]);
        this.counterReload = to!bool(state["apu.triangle.counterReload"]);
    }
}

// Noise

struct Noise {
    bool   enabled;
    bool   mode;
    ushort shiftRegister;
    bool   lengthEnabled;
    ubyte  lengthValue;
    ushort timerPeriod;
    ushort timerValue;
    bool   envelopeEnabled;
    bool   envelopeLoop;
    bool   envelopeStart;
    ubyte  envelopePeriod;
    ubyte  envelopeValue;
    ubyte  envelopeVolume;
    ubyte  constantVolume;

    void writeControl(ubyte value) {
        this.lengthEnabled = ((value >> 5) & 1) == 0;
        this.envelopeLoop = ((value >> 5) & 1) == 1;
        this.envelopeEnabled = ((value >> 4) & 1) == 0;
        this.envelopePeriod = value & 15;
        this.constantVolume = value & 15;
        this.envelopeStart = true;
    }

    void writePeriod(ubyte value) {
        this.mode = (value & 0x80) == 0x80;
        this.timerPeriod = noiseTable[value & 0x0F];
    }

    void writeLength(ubyte value) {
        this.lengthValue = lengthTable[value >> 3];
        this.envelopeStart = true;
    }

    void stepTimer() {
        if (this.timerValue == 0) {
            this.timerValue = this.timerPeriod;
            ubyte shift;
            if (this.mode) {
                shift = 6;
            } else {
                shift = 1;
            }
            auto b1 = this.shiftRegister & 1;
            auto b2 = (this.shiftRegister >> shift) & 1;
            this.shiftRegister >>= 1;
            this.shiftRegister |= (b1 ^ b2) << 14;
        } else {
            this.timerValue--;
        }
    }

    void stepEnvelope() {
        if (this.envelopeStart) {
            this.envelopeVolume = 15;
            this.envelopeValue = this.envelopePeriod;
            this.envelopeStart = false;
        } else if (this.envelopeValue > 0) {
            this.envelopeValue--;
        } else {
            if (this.envelopeVolume > 0) {
                this.envelopeVolume--;
            } else if (this.envelopeLoop) {
                this.envelopeVolume = 15;
            }
            this.envelopeValue = this.envelopePeriod;
        }
    }

    void stepLength() {
        if (this.lengthEnabled && this.lengthValue > 0) {
            this.lengthValue--;
        }
    }

    ubyte output() {
        if (!this.enabled) {
            return 0;
        }
        if (this.lengthValue == 0) {
            return 0;
        }
        if ((this.shiftRegister & 1) == 1) {
            return 0;
        }
        if (this.envelopeEnabled) {
            return this.envelopeVolume;
        } else {
            return this.constantVolume;
        }
    }

    void save(string[string] state) {
        state["apu.noise.enabled"] = to!string(this.enabled);
        state["apu.noise.mode"] = to!string(this.mode);
        state["apu.noise.shiftRegister"] = to!string(this.shiftRegister);
        state["apu.noise.lengthEnabled"] = to!string(this.lengthEnabled);
        state["apu.noise.lengthValue"] = to!string(this.lengthValue);
        state["apu.noise.timerPeriod"] = to!string(this.timerPeriod);
        state["apu.noise.timerValue"] = to!string(this.timerValue);
        state["apu.noise.envelopeEnabled"] = to!string(this.envelopeEnabled);
        state["apu.noise.envelopeLoop"] = to!string(this.envelopeLoop);
        state["apu.noise.envelopeStart"] = to!string(this.envelopeStart);
        state["apu.noise.envelopePeriod"] = to!string(this.envelopePeriod);
        state["apu.noise.envelopeValue"] = to!string(this.envelopeValue);
        state["apu.noise.envelopeVolume"] = to!string(this.envelopeVolume);
        state["apu.noise.constantVolume"] = to!string(this.constantVolume);
    }

    void load(string[string] state) {
        this.enabled = to!bool(state["apu.noise.enabled"]);
        this.mode = to!bool(state["apu.noise.mode"]);
        this.shiftRegister = to!ushort(state["apu.noise.shiftRegister"]);
        this.lengthEnabled = to!bool(state["apu.noise.lengthEnabled"]);
        this.lengthValue = to!ubyte(state["apu.noise.lengthValue"]);
        this.timerPeriod = to!ushort(state["apu.noise.timerPeriod"]);
        this.timerValue = to!ushort(state["apu.noise.timerValue"]);
        this.envelopeEnabled = to!bool(state["apu.noise.envelopeEnabled"]);
        this.envelopeLoop = to!bool(state["apu.noise.envelopeLoop"]);
        this.envelopeStart = to!bool(state["apu.noise.envelopeStart"]);
        this.envelopePeriod = to!ubyte(state["apu.noise.envelopePeriod"]);
        this.envelopeValue = to!ubyte(state["apu.noise.envelopeValue"]);
        this.envelopeVolume = to!ubyte(state["apu.noise.envelopeVolume"]);
        this.constantVolume = to!ubyte(state["apu.noise.constantVolume"]);
    }
}

// DMC

struct DMC {
    CPU    cpu;
    bool   enabled;
    ubyte  value;
    ushort sampleAddress;
    ushort sampleLength;
    ushort currentAddress;
    ushort currentLength;
    ubyte  shiftRegister;
    ubyte  bitCount;
    ubyte  tickPeriod;
    ubyte  tickValue;
    bool   loop;
    bool   irq;

    void writeControl(ubyte value) {
        this.irq = (value & 0x80) == 0x80;
        this.loop = (value & 0x40) == 0x40;
        this.tickPeriod = dmcTable[value & 0x0F];
    }

    void writeValue(ubyte value) {
        this.value = value & 0x7F;
    }

    void writeAddress(ubyte value) {
        // Sample address = %11AAAAAA.AA000000
        this.sampleAddress = 0xC000 | (cast(ushort)value << 6);
    }

    void writeLength(ubyte value) {
        // Sample length = %0000LLLL.LLLL0001
        this.sampleLength = (cast(ushort)value << 4) | 1;
    }

    void restart() {
        this.currentAddress = this.sampleAddress;
        this.currentLength = this.sampleLength;
    }

    void stepTimer() {
        if (!this.enabled) {
            return;
        }
        this.stepReader();
        if (this.tickValue == 0) {
            this.tickValue = this.tickPeriod;
            this.stepShifter();
        } else {
            this.tickValue--;
        }
    }

    void stepReader() {
        if (this.currentLength > 0 && this.bitCount == 0) {
            this.cpu.stall += 4;
            this.shiftRegister = this.cpu.read(this.currentAddress);
            this.bitCount = 8;
            this.currentAddress++;
            if (this.currentAddress == 0) {
                this.currentAddress = 0x8000;
            }
            this.currentLength--;
            if (this.currentLength == 0 && this.loop) {
                this.restart();
            }
        }
    }

    void stepShifter() {
        if (this.bitCount == 0) {
            return;
        }
        if ((this.shiftRegister & 1) == 1) {
            if (this.value <= 125) {
                this.value += 2;
            }
        } else {
            if (this.value >= 2) {
                this.value -= 2;
            }
        }
        this.shiftRegister >>= 1;
        this.bitCount--;
    }

    ubyte output() {
        return this.value;
    }

    void save(string[string] state) {
        state["apu.dmc.enabled"] = to!string(this.enabled);
        state["apu.dmc.value"] = to!string(this.value);
        state["apu.dmc.sampleAddress"] = to!string(this.sampleAddress);
        state["apu.dmc.sampleLength"] = to!string(this.sampleLength);
        state["apu.dmc.currentAddress"] = to!string(this.currentAddress);
        state["apu.dmc.currentLength"] = to!string(this.currentLength);
        state["apu.dmc.shiftRegister"] = to!string(this.shiftRegister);
        state["apu.dmc.bitCount"] = to!string(this.bitCount);
        state["apu.dmc.tickPeriod"] = to!string(this.tickPeriod);
        state["apu.dmc.tickValue"] = to!string(this.tickValue);
        state["apu.dmc.loop"] = to!string(this.loop);
        state["apu.dmc.irq"] = to!string(this.irq);
    }

    void load(string[string] state) {
        this.enabled = to!bool(state["apu.dmc.enabled"]);
        this.value = to!ubyte(state["apu.dmc.value"]);
        this.sampleAddress = to!ushort(state["apu.dmc.sampleAddress"]);
        this.sampleLength = to!ushort(state["apu.dmc.sampleLength"]);
        this.currentAddress = to!ushort(state["apu.dmc.currentAddress"]);
        this.currentLength = to!ushort(state["apu.dmc.currentLength"]);
        this.shiftRegister = to!ubyte(state["apu.dmc.shiftRegister"]);
        this.bitCount = to!ubyte(state["apu.dmc.bitCount"]);
        this.tickPeriod = to!ubyte(state["apu.dmc.tickPeriod"]);
        this.tickValue = to!ubyte(state["apu.dmc.tickValue"]);
        this.loop = to!bool(state["apu.dmc.loop"]);
        this.irq = to!bool(state["apu.dmc.irq"]);
    }
}
