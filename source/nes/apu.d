module nes.apu;

import std.conv;
import std.math;
import std.stdio;

import nes.console;
import nes.cpu;

import blip_buf;

enum MAX_SAMPLE_RATE = 96000;

ulong[6][2] stepCycles = [[7457, 14913, 22371, 29828, 29829, 29830],
                          [7457, 14913, 22371, 29829, 37281, 37282]];

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

alias void delegate(short) ApuCallbackFuncType;

class APU {
    this(Console console) {
        this.console = console;
        this.pulse1.channel = 1;
        this.pulse2.channel = 2;
        this.dmc.cpu = console.cpu;

        this.blipBuf = blip_new(MAX_SAMPLE_RATE);

        this.reset(true);
    }

    ~this() {
        blip_delete(this.blipBuf);
    }

    void step() {
        auto cycle1 = this.cycle;
        this.cycle++;
        auto cycle2 = this.cycle;

        this.counter++;

        if (this.counter >= stepCycles[this.stepMode][this.currentStep]) {
            this.stepFrameCounter();
        }

        if (this.frameCounterValue >= 0 && this.frameCounterDelay > 0)
            tryDelayedFrameCounterWrite();

        if (this.blockFrameCounterTick > 0) {
            this.blockFrameCounterTick--;
        }

        this.stepTimer();

        short currentOutput = floatSampleToShort(this.output());

        short delta = cast(short)(currentOutput - this.blipPrevOutput);

        if (delta != 0) blip_add_delta(this.blipBuf, this.outputTick, delta);

        this.blipPrevOutput = currentOutput;

        this.outputTick++;

        auto s1 = cast(int)(cast(double)cycle1 / this.ticksPerSample);
        auto s2 = cast(int)(cast(double)cycle2 / this.ticksPerSample);
        if (s1 != s2) {
           this.sendSample();
           this.outputTick = 0;
        }
    }

    void reset(bool powerUp = false) {
        this.cycle = 0;
        this.counter = 0;
        this.currentStep = 0;

        this.inhibitIRQ = false;
        this.frameIRQ = false;

        this.frameCounterDelay = -1;
        this.frameCounterValue = -1;
        this.blockFrameCounterTick = 0;

        this.writeControl(0);

        this.pulse1.reset();
        this.pulse2.reset();
        this.triangle.reset(powerUp);
        this.noise.reset();
        this.dmc.reset();

        this.outputTick = 0;

        blip_clear(this.blipBuf);

        foreach (_; 0 .. 8)
            this.step();
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

    void setAudioSampleRate(double sampleRate) {
        if (sampleRate != 0) {
            if (sampleRate > MAX_SAMPLE_RATE) sampleRate = MAX_SAMPLE_RATE;

            // Convert samples per second to cpu steps per sample
            this.ticksPerSample = CPUFrequency / sampleRate;

            blip_set_rates(this.blipBuf, CPUFrequency, sampleRate);
        }
    }

    void save(string[string] state) {
        state["apu.cycle"] = to!string(this.cycle);
        state["apu.frameIRQ"] = to!string(this.frameIRQ);
        state["apu.inhibitIRQ"] = to!string(this.inhibitIRQ);

        state["apu.counter"] = to!string(this.counter);
        state["apu.stepMode"] = to!string(this.stepMode);
        state["apu.currentStep"] = to!string(this.currentStep);
        state["apu.frameCounterValue"] = to!string(this.frameCounterValue);
        state["apu.frameCounterDelay"] = to!string(this.frameCounterDelay);
        state["apu.blockFrameCounterTick"] = to!string(this.blockFrameCounterTick);

        this.pulse1.save(state);
        this.pulse2.save(state);
        this.triangle.save(state);
        this.noise.save(state);
        this.dmc.save(state);
    }

    void load(string[string] state) {
        this.cycle = to!ulong(state["apu.cycle"]);
        this.frameIRQ = to!bool(state["apu.frameIRQ"]);
        this.inhibitIRQ = to!bool(state["apu.inhibitIRQ"]);

        this.counter = to!ulong(state["apu.counter"]);
        this.stepMode = to!uint(state["apu.stepMode"]);
        this.currentStep = to!uint(state["apu.currentStep"]);
        this.frameCounterValue = to!short(state["apu.frameCounterValue"]);
        this.frameCounterDelay = to!byte(state["apu.frameCounterDelay"]);
        this.blockFrameCounterTick = to!ubyte(state["apu.blockFrameCounterTick"]);

        this.pulse1.load(state);
        this.pulse2.load(state);
        this.triangle.load(state);
        this.noise.load(state);
        this.dmc.load(state);
    }

    package:
        ApuCallbackFuncType callback;

        Console  console;
        Pulse    pulse1;
        Pulse    pulse2;
        Triangle triangle;
        Noise    noise;
        DMC      dmc;
        ulong    cycle, counter;
        bool     inhibitIRQ;
        bool     frameIRQ;

    private:
        uint    stepMode, currentStep;
        short   frameCounterValue;
        byte    frameCounterDelay;
        ubyte   blockFrameCounterTick;
        blip_t* blipBuf;
        double  ticksPerSample;
        uint    outputTick;
        short   blipOutput, blipPrevOutput;
        short[MAX_SAMPLE_RATE] outBuf;

        void sendSample() {
            if (this.callback == null) return;

            blip_end_frame(this.blipBuf, this.outputTick);

            auto sampleCount = blip_read_samples(this.blipBuf, outBuf.ptr,
                MAX_SAMPLE_RATE, 0);

            for (uint i = 0; i < sampleCount; i++) {
                this.callback(outBuf[i]);
            }
        }

        short floatSampleToShort(float f) {
            if (f > 1.0) f = 1.0;
            if (f < -1.0) f = -1.0;
            return cast(short)(f * 0x7fff);
        }

        float output() {
            auto p1 = this.pulse1.output();
            auto p2 = this.pulse2.output();
            auto t = this.triangle.output();
            auto n = this.noise.output();
            auto d = this.dmc.output();

            float pulseOut, tndOut;

            pulseOut = pulseTable[p1 + p2];
            tndOut = tndTable[3 * t + 2 * n + d];

            return pulseOut + tndOut;
        }

        // mode 0:    mode 1:       function
        // ---------  -----------  -----------------------------
        //  - - - f    - - - - -    IRQ (if bit 6 is clear)
        //  - l - l    l - l - -    Length counter and sweep
        //  e e e e    e e e e -    Envelope and linear counter
        void stepFrameCounter() {
            if (this.currentStep == 0 || this.currentStep == 2) {
                if (!this.blockFrameCounterTick) {
                    this.stepEnvelope();

                    this.blockFrameCounterTick = 2;
                }
            }
            else if (this.currentStep == 1 || this.currentStep == 4) {
                if (!this.blockFrameCounterTick) {
                    this.stepEnvelope();

                    this.stepSweep();
                    this.stepLength();

                    this.blockFrameCounterTick = 2;
                }

                if (this.currentStep == 4 && this.stepMode == 0 && !this.inhibitIRQ) {
                    this.frameIRQ = true;
                }
            }
            else if (this.currentStep == 3 || this.currentStep == 5) {
                if (this.stepMode == 0) {
                    if (!this.inhibitIRQ) {
                        this.frameIRQ = true;

                        if (this.currentStep == 3) {
                            this.console.cpu.addIrqSource(IrqSource.FrameCounter);
                        }
                    }
                }
            }

            this.currentStep++;
            if (this.currentStep == 6) {
                this.currentStep = 0;
                this.counter = 0;
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
            if (this.frameIRQ) {
                result |= 64;
            }
            if (this.console.cpu.hasIrqSource(IrqSource.DMC)) {
                result |= 128;
            }

            this.frameIRQ = false;
            this.console.cpu.clearIrqSource(IrqSource.FrameCounter);

            return result;
        }

        void writeControl(ubyte value) {
            this.console.cpu.clearIrqSource(IrqSource.DMC);

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
            this.frameCounterValue = value;

            /**
             * If the write occurs during an APU cycle, the effects occur 3 CPU cycles after the $4017 write cycle,
             *  and if the write occurs between APU cycles, the effects occurs 4 CPU cycles after the write cycle.
             * First CPU cycle we see is odd so even cycles are APU cycles.
             */
            this.frameCounterDelay = (this.console.cpu.cycles & 0x01) == 1 ? 4 : 3;

            this.inhibitIRQ = ((value >> 6) & 1) == 1;

            if (this.inhibitIRQ) {
                this.frameIRQ = false;
                this.console.cpu.clearIrqSource(IrqSource.FrameCounter);
            }
        }

        void tryDelayedFrameCounterWrite() {
            this.frameCounterDelay--;

            if (this.frameCounterDelay == 0) {
                ubyte value = cast(ubyte)this.frameCounterValue;

                this.stepMode = ((value >> 7) & 1) ? 1 : 0;

                if (this.stepMode == 1 && !this.blockFrameCounterTick) {
                    this.stepEnvelope();
                    this.stepSweep();
                    this.stepLength();

                    this.blockFrameCounterTick = 2;
                }

                this.currentStep = 0;
                this.counter = 0;
                this.frameCounterDelay = -1;
                this.frameCounterValue = -1;
            }
        }
}

// Pulse

struct Pulse {
    bool   enabled;
    ubyte  channel;
    bool   lengthEnabled;
    bool   lengthEnabledNewValue;
    ubyte  lengthValue;
    ubyte  lengthValueNew;
    ubyte  lengthValuePrev;
    ushort timerPeriod;
    ushort timerValue;
    ubyte  dutyMode;
    ubyte  dutyValue;
    bool   sweepReload;
    bool   sweepEnabled;
    bool   sweepNegate;
    ubyte  sweepShift;
    ubyte  sweepPeriod;
    uint   sweepTargetPeriod;
    ubyte  sweepValue;
    bool   envelopeEnabled;
    bool   envelopeLoop;
    bool   envelopeStart;
    byte   envelopeDivider;
    ubyte  envelopeCounter;
    ubyte  envelopeConstantVolume;

    void reset() {
        this.dutyMode = 0;
        this.dutyValue = 0;

        this.timerPeriod = 0;

        this.sweepEnabled = false;
        this.sweepPeriod = 1;
        this.sweepNegate = false;
        this.sweepShift = 0;
        this.sweepReload = true;
        this.sweepValue = 0;
        this.sweepTargetPeriod = 0;
        this.updateSweepTargetPeriod();

        this.lengthEnabled = true;
        this.lengthEnabledNewValue = true;
        this.lengthValue = 0;
        this.lengthValueNew = 0;
        this.lengthValuePrev = 0;

        this.envelopeEnabled = false;
        this.envelopeLoop = false;
        this.envelopeConstantVolume = 0;
        this.envelopeCounter = 0;
        this.envelopeStart = false;
        this.envelopeDivider = 0;
    }

    // 0x4000 & 0x4004
    void writeControl(ubyte value) {
        this.dutyMode = (value >> 6) & 3;
        this.lengthEnabledNewValue = ((value >> 5) & 1) == 0;
        this.envelopeLoop = ((value >> 5) & 1) == 1;
        this.envelopeEnabled = ((value >> 4) & 1) == 0;
        this.envelopeConstantVolume = value & 15;
    }

    // 0x4001 & 0x4005
    void writeSweep(ubyte value) {
        this.sweepEnabled = ((value >> 7) & 1) == 1;
        this.sweepPeriod = ((value >> 4) & 7) + 1;
        this.sweepNegate = ((value >> 3) & 1) == 1;
        this.sweepShift = value & 7;
        this.sweepReload = true;
        this.updateSweepTargetPeriod();
    }

    // 0x4002 & 0x4006
    void writeTimerLow(ubyte value) {
        this.timerPeriod = (this.timerPeriod & 0xFF00) | cast(ushort)value;
        this.updateSweepTargetPeriod();
    }

    // 0x4003 & 0x4007
    void writeTimerHigh(ubyte value) {
        if (this.enabled) {
            this.lengthValueNew = lengthTable[value >> 3];
            this.lengthValuePrev = this.lengthValue;
        }

        this.timerPeriod = (this.timerPeriod & 0x00FF) | (cast(ushort)(value & 7) << 8);
        this.updateSweepTargetPeriod();
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
            this.envelopeStart = false;
            this.envelopeCounter = 15;
            this.envelopeDivider = this.envelopeConstantVolume;
        }  else {
            this.envelopeDivider--;

            if (this.envelopeDivider < 0) {
                this.envelopeDivider = this.envelopeConstantVolume;
                if (this.envelopeCounter > 0) {
                    this.envelopeCounter--;
                }
                else if (this.envelopeLoop)
                    this.envelopeCounter = 15;
            }
        }
    }

    void stepSweep() {
        this.sweepValue--;
        if (this.sweepValue == 0) {
            if (this.sweepShift > 0 && this.sweepEnabled && this.timerPeriod >= 8 && this.sweepTargetPeriod <= 0x7ff) {
                this.timerPeriod = cast(ushort)this.sweepTargetPeriod;
                this.updateSweepTargetPeriod();
            }
            this.sweepValue = this.sweepPeriod;
        }

        if (this.sweepReload) {
            this.sweepValue = this.sweepPeriod;
            this.sweepReload = false;
        }
    }

    void stepLength() {
        if (this.lengthEnabled && this.lengthValue > 0) {
            this.lengthValue--;
        }
    }

    void updateSweepTargetPeriod() {
        auto delta = this.timerPeriod >> this.sweepShift;
        if (this.sweepNegate) {
            this.sweepTargetPeriod = this.timerPeriod - delta;
            if (this.channel == 1) {
                this.sweepTargetPeriod--;
            }
        } else {
            this.sweepTargetPeriod = this.timerPeriod + delta;
        }
    }

    ubyte output() {
        // Emulate 1 cycle delay
        this.lengthEnabled = this.lengthEnabledNewValue;

        // Emulate 1 cycle delay
        if (this.lengthValueNew) {
            if (this.lengthValue == this.lengthValuePrev) {
                this.lengthValue = this.lengthValueNew;
            }

            this.lengthValueNew = 0;
        }

        if (!this.enabled) {
            return 0;
        }
        if (this.lengthValue == 0) {
            return 0;
        }
        if (this.timerPeriod < 8 || (!this.sweepNegate && this.sweepTargetPeriod > 0x7FF)) {
            return 0;
        }
        if (this.envelopeEnabled) {
            return cast(ubyte)(dutyTable[this.dutyMode][this.dutyValue] * this.envelopeCounter);
        } else {
            return cast(ubyte)(dutyTable[this.dutyMode][this.dutyValue] * this.envelopeConstantVolume);
        }
    }

    void save(string[string] state) {
        auto id = "apu.pulse" ~ to!string(this.channel);

        state[id ~ ".enabled"] = to!string(this.enabled);
        state[id ~ ".channel"] = to!string(this.channel);
        state[id ~ ".lengthEnabled"] = to!string(this.lengthEnabled);
        state[id ~ ".lengthEnabledNewValue"] = to!string(this.lengthEnabledNewValue);
        state[id ~ ".lengthValue"] = to!string(this.lengthValue);
        state[id ~ ".lengthValueNew"] = to!string(this.lengthValueNew);
        state[id ~ ".lengthValuePrev"] = to!string(this.lengthValuePrev);
        state[id ~ ".timerPeriod"] = to!string(this.timerPeriod);
        state[id ~ ".timerValue"] = to!string(this.timerValue);
        state[id ~ ".dutyMode"] = to!string(this.dutyMode);
        state[id ~ ".dutyValue"] = to!string(this.dutyValue);
        state[id ~ ".sweepReload"] = to!string(this.sweepReload);
        state[id ~ ".sweepEnabled"] = to!string(this.sweepEnabled);
        state[id ~ ".sweepNegate"] = to!string(this.sweepNegate);
        state[id ~ ".sweepShift"] = to!string(this.sweepShift);
        state[id ~ ".sweepPeriod"] = to!string(this.sweepPeriod);
        state[id ~ ".sweepTargetPeriod"] = to!string(this.sweepTargetPeriod);
        state[id ~ ".sweepValue"] = to!string(this.sweepValue);
        state[id ~ ".envelopeEnabled"] = to!string(this.envelopeEnabled);
        state[id ~ ".envelopeLoop"] = to!string(this.envelopeLoop);
        state[id ~ ".envelopeStart"] = to!string(this.envelopeStart);
        state[id ~ ".envelopeDivider"] = to!string(this.envelopeDivider);
        state[id ~ ".envelopeCounter"] = to!string(this.envelopeCounter);
        state[id ~ ".envelopeConstantVolume"] = to!string(this.envelopeConstantVolume);
    }

    void load(string[string] state) {
        auto id = "apu.pulse" ~ to!string(this.channel);

        this.enabled = to!bool(state[id ~ ".enabled"]);
        this.channel = to!ubyte(state[id ~ ".channel"]);
        this.lengthEnabled = to!bool(state[id ~ ".lengthEnabled"]);
        this.lengthEnabledNewValue = to!bool(state[id ~ ".lengthEnabledNewValue"]);
        this.lengthValue = to!ubyte(state[id ~ ".lengthValue"]);
        this.lengthValueNew = to!ubyte(state[id ~ ".lengthValueNew"]);
        this.lengthValuePrev = to!ubyte(state[id ~ ".lengthValuePrev"]);
        this.timerPeriod = to!ushort(state[id ~ ".timerPeriod"]);
        this.timerValue = to!ushort(state[id ~ ".timerValue"]);
        this.dutyMode = to!ubyte(state[id ~ ".dutyMode"]);
        this.dutyValue = to!ubyte(state[id ~ ".dutyValue"]);
        this.sweepReload = to!bool(state[id ~ ".sweepReload"]);
        this.sweepEnabled = to!bool(state[id ~ ".sweepEnabled"]);
        this.sweepNegate = to!bool(state[id ~ ".sweepNegate"]);
        this.sweepShift = to!ubyte(state[id ~ ".sweepShift"]);
        this.sweepPeriod = to!ubyte(state[id ~ ".sweepPeriod"]);
        this.sweepTargetPeriod = to!uint(state[id ~ ".sweepTargetPeriod"]);
        this.sweepValue = to!ubyte(state[id ~ ".sweepValue"]);
        this.envelopeEnabled = to!bool(state[id ~ ".envelopeEnabled"]);
        this.envelopeLoop = to!bool(state[id ~ ".envelopeLoop"]);
        this.envelopeStart = to!bool(state[id ~ ".envelopeStart"]);
        this.envelopeDivider = to!ubyte(state[id ~ ".envelopeDivider"]);
        this.envelopeCounter = to!ubyte(state[id ~ ".envelopeCounter"]);
        this.envelopeConstantVolume = to!ubyte(state[id ~ ".envelopeConstantVolume"]);
    }
}

// Triangle

struct Triangle {
    CPU cpu;
    bool   enabled;
    bool   lengthEnabled;
    bool   lengthEnabledNewValue;
    ubyte  lengthValue;
    ubyte  lengthValueNew;
    ubyte  lengthValuePrev;
    ushort timerPeriod;
    ushort timerValue;
    ubyte  dutyValue;
    ubyte  counterPeriod;
    ubyte  counterValue;
    bool   counterReload;

    void reset(bool powerUp) {
        this.enabled = false;

        this.timerPeriod = 0;
        this.timerValue = 0;

        // apu_reset: len_ctrs_enabled
        // "At reset, length counters should be enabled, triangle unaffected"
        if (powerUp) {
            this.lengthEnabled = true;
            this.lengthEnabledNewValue = true;
            this.lengthValue = 0;
            this.lengthValueNew = 0;
            this.lengthValuePrev = 0;
        }

        this.counterValue = 0;
        this.counterPeriod = 0;
        this.counterReload = false;

        this.dutyValue = 0; // hack to "fix" apu_mixer test
    }

    // 0x4008
    void writeControl(ubyte value) {
        this.lengthEnabledNewValue = ((value >> 7) & 1) == 0;
        this.counterPeriod = value & 0x7F;
    }

    // 0x400A
    void writeTimerLow(ubyte value) {
        this.timerPeriod = (this.timerPeriod & 0xFF00) | cast(ushort)value;
    }

    // 0x400B
    void writeTimerHigh(ubyte value) {
        if (this.enabled) {
            this.lengthValueNew = lengthTable[value >> 3];
            this.lengthValuePrev = this.lengthValue;
        }

        this.timerPeriod = (this.timerPeriod & 0x00FF) | (cast(ushort)(value & 7) << 8);

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
        // Emulate 1 cycle delay
        this.lengthEnabled = this.lengthEnabledNewValue;

        // Emulate 1 cycle delay
        if (this.lengthValueNew) {
            if (this.lengthValue == this.lengthValuePrev) {
                this.lengthValue = this.lengthValueNew;
            }

            this.lengthValueNew = 0;
        }

        if (!this.enabled) {
            return 0;
        }

        return triangleTable[this.dutyValue];
    }

    void save(string[string] state) {
        state["apu.triangle.enabled"] = to!string(this.enabled);
        state["apu.triangle.lengthEnabled"] = to!string(this.lengthEnabled);
        state["apu.triangle.lengthEnabledNewValue"] = to!string(this.lengthEnabledNewValue);
        state["apu.triangle.lengthValue"] = to!string(this.lengthValue);
        state["apu.triangle.lengthValueNew"] = to!string(this.lengthValueNew);
        state["apu.triangle.lengthValuePrev"] = to!string(this.lengthValuePrev);
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
        this.lengthEnabledNewValue = to!bool(state["apu.triangle.lengthEnabledNewValue"]);
        this.lengthValue = to!ubyte(state["apu.triangle.lengthValue"]);
        this.lengthValueNew = to!ubyte(state["apu.triangle.lengthValueNew"]);
        this.lengthValuePrev = to!ubyte(state["apu.triangle.lengthValuePrev"]);
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
    bool   lengthEnabledNewValue;
    ubyte  lengthValue;
    ubyte  lengthValueNew;
    ubyte  lengthValuePrev;
    ushort timerPeriod;
    ushort timerValue;
    bool   envelopeEnabled;
    bool   envelopeLoop;
    bool   envelopeStart;
    byte   envelopeDivider;
    ubyte  envelopeCounter;
    ubyte  envelopeConstantVolume;

    void reset() {
        this.timerPeriod = cast(ushort)(noiseTable[0] - 1);
        this.shiftRegister = 1;
        this.mode = false;

        this.lengthEnabled = true;
        this.lengthEnabledNewValue = true;
        this.lengthValue = 0;
        this.lengthValueNew = 0;
        this.lengthValuePrev = 0;

        this.envelopeEnabled = false;
        this.envelopeLoop = false;
        this.envelopeConstantVolume = 0;
        this.envelopeCounter = 0;
        this.envelopeStart = false;
        this.envelopeDivider = 0;
    }

    // 0x400C
    void writeControl(ubyte value) {
        this.lengthEnabledNewValue = ((value >> 5) & 1) == 0;
        this.envelopeLoop = ((value >> 5) & 1) == 1;
        this.envelopeEnabled = ((value >> 4) & 1) == 0;
        this.envelopeConstantVolume = value & 15;
    }

    // 0x400E
    void writePeriod(ubyte value) {
        this.mode = (value & 0x80) == 0x80;
        this.timerPeriod = cast(ushort)(noiseTable[value & 0x0F] - 1);
    }

    // 0x400F
    void writeLength(ubyte value) {
        if (this.enabled) {
            this.lengthValueNew = lengthTable[value >> 3];
            this.lengthValuePrev = this.lengthValue;
        }

        this.envelopeStart = true;
    }

    void stepTimer() {
        if (this.timerValue == 0) {
            this.timerValue = this.timerPeriod;

            ushort feedback = (this.shiftRegister & 0x01) ^ ((this.shiftRegister >> (this.mode ? 6 : 1)) & 0x01);
            this.shiftRegister >>= 1;
            this.shiftRegister |= (feedback << 14);
        } else {
            this.timerValue--;
        }
    }

    void stepEnvelope() {
        if (this.envelopeStart) {
            this.envelopeStart = false;
            this.envelopeCounter = 15;
            this.envelopeDivider = this.envelopeConstantVolume;
        }  else {
            this.envelopeDivider--;

            if (this.envelopeDivider < 0) {
                this.envelopeDivider = this.envelopeConstantVolume;
                if (this.envelopeCounter > 0) {
                    this.envelopeCounter--;
                }
                else if (this.envelopeLoop)
                    this.envelopeCounter = 15;
            }
        }
    }

    void stepLength() {
        if (this.lengthEnabled && this.lengthValue > 0) {
            this.lengthValue--;
        }
    }

    ubyte output() {
        // Emulate 1 cycle delay
        this.lengthEnabled = this.lengthEnabledNewValue;

        // Emulate 1 cycle delay
        if (this.lengthValueNew) {
            if (this.lengthValue == this.lengthValuePrev) {
                this.lengthValue = this.lengthValueNew;
            }

            this.lengthValueNew = 0;
        }

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
            return this.envelopeCounter;
        } else {
            return this.envelopeConstantVolume;
        }
    }

    void save(string[string] state) {
        state["apu.noise.enabled"] = to!string(this.enabled);
        state["apu.noise.mode"] = to!string(this.mode);
        state["apu.noise.shiftRegister"] = to!string(this.shiftRegister);
        state["apu.noise.lengthEnabled"] = to!string(this.lengthEnabled);
        state["apu.noise.lengthEnabledNewValue"] = to!string(this.lengthEnabledNewValue);
        state["apu.noise.lengthValue"] = to!string(this.lengthValue);
        state["apu.noise.lengthValueNew"] = to!string(this.lengthValueNew);
        state["apu.noise.lengthValuePrev"] = to!string(this.lengthValuePrev);
        state["apu.noise.timerPeriod"] = to!string(this.timerPeriod);
        state["apu.noise.timerValue"] = to!string(this.timerValue);
        state["apu.noise.envelopeEnabled"] = to!string(this.envelopeEnabled);
        state["apu.noise.envelopeLoop"] = to!string(this.envelopeLoop);
        state["apu.noise.envelopeStart"] = to!string(this.envelopeStart);
        state["apu.noise.envelopeDivider"] = to!string(this.envelopeDivider);
        state["apu.noise.envelopeCounter"] = to!string(this.envelopeCounter);
        state["apu.noise.envelopeConstantVolume"] = to!string(this.envelopeConstantVolume);
    }

    void load(string[string] state) {
        this.enabled = to!bool(state["apu.noise.enabled"]);
        this.mode = to!bool(state["apu.noise.mode"]);
        this.shiftRegister = to!ushort(state["apu.noise.shiftRegister"]);
        this.lengthEnabled = to!bool(state["apu.noise.lengthEnabled"]);
        this.lengthEnabledNewValue = to!bool(state["apu.noise.lengthEnabledNewValue"]);
        this.lengthValue = to!ubyte(state["apu.noise.lengthValue"]);
        this.lengthValueNew = to!ubyte(state["apu.noise.lengthValueNew"]);
        this.lengthValuePrev = to!ubyte(state["apu.noise.lengthValuePrev"]);
        this.timerPeriod = to!ushort(state["apu.noise.timerPeriod"]);
        this.timerValue = to!ushort(state["apu.noise.timerValue"]);
        this.envelopeEnabled = to!bool(state["apu.noise.envelopeEnabled"]);
        this.envelopeLoop = to!bool(state["apu.noise.envelopeLoop"]);
        this.envelopeStart = to!bool(state["apu.noise.envelopeStart"]);
        this.envelopeDivider = to!ubyte(state["apu.noise.envelopeDivider"]);
        this.envelopeCounter = to!ubyte(state["apu.noise.envelopeCounter"]);
        this.envelopeConstantVolume = to!ubyte(state["apu.noise.envelopeConstantVolume"]);
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

    void reset() {
        this.tickPeriod = cast(ubyte)(dmcTable[0] - 1);
        this.bitCount = 8;

        this.value = 0;
        this.sampleAddress = 0;
        this.sampleLength = 0;
        this.currentAddress = 0;
        this.currentLength = 0;
        this.shiftRegister = 0;
        this.loop = false;
        this.irq = false;
    }

    // 0x4010
    void writeControl(ubyte value) {
        this.irq = (value & 0x80) == 0x80;
        this.loop = (value & 0x40) == 0x40;
        this.tickPeriod = cast(ubyte)(dmcTable[value & 0x0F] - 1);

        if (!this.irq) this.cpu.clearIrqSource(IrqSource.DMC);
    }

    // 0x4011
    void writeValue(ubyte value) {
        this.value = value & 0x7F;
    }

    // 0x4012
    void writeAddress(ubyte value) {
        // Sample address = %11AAAAAA.AA000000
        this.sampleAddress = 0xC000 | (cast(ushort)value << 6);
    }

    // 0x4013
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
            if (this.currentLength == 0) {
                if (this.loop) {
                    this.restart();
                }
                else if (this.irq) {
                    this.cpu.addIrqSource(IrqSource.DMC);
                }
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
