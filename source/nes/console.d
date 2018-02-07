module nes.console;

import std.base64;
import std.conv;
import std.file;
import std.zlib;

import nes.apu;
import nes.cartridge;
import nes.color;
import nes.controller;
import nes.cpu;
import nes.filter;
import nes.image;
import nes.ines;
import nes.mapper;
import nes.palette;
import nes.ppu;

class Console {
    CPU        cpu;
    APU        apu;
    PPU        ppu;
    Cartridge  cartridge;
    Controller controller1;
    Controller controller2;
    Mapper     mapper;
    ubyte[]    ram;

    this(string path) {
        this.cartridge = LoadNESFile(path);

        this.ram = new ubyte[2048];
        this.controller1 = new Controller();
        this.controller2 = new Controller();

        this.mapper = NewMapper(this);

        this.cpu = new CPU(this);
        this.apu = new APU(this);
        this.ppu = new PPU(this);
    }

    void reset() {
        this.cpu.reset();
    }

    int step() {
        auto cpuCycles = this.cpu.step();
        auto ppuCycles = cpuCycles * 3;

        foreach (_; 0 .. ppuCycles) {
            this.ppu.step();
            this.mapper.step();
        }

        foreach (_; 0 .. cpuCycles) {
            this.apu.step();
        }

        return cpuCycles;
    }

    int stepFrame() {
        auto cpuCycles = 0;
        auto frame = this.ppu.frame;

        while (frame == this.ppu.frame) {
            cpuCycles += this.step();
        }

        return cpuCycles;
    }

    void stepSeconds(double seconds) {
        auto cycles = cast(int)(CPUFrequency * seconds);

        while (cycles > 0) {
            cycles -= this.step();
        }
    }

    ImageRGBA buffer() {
        return this.ppu.front;
    }

    RGBA backgroundColor() {
        return Palette[this.ppu.readPalette(0) % 64];
    }

    void setButtons1(bool[8] buttons) {
        this.controller1.setButtons(buttons);
    }

    void setButtons2(bool[8] buttons) {
        this.controller2.setButtons(buttons);
    }

    void setAudioCallback(ApuCallbackFuncType callback) {
        this.apu.callback = callback;
    }

    void setAudioSampleRate(double sampleRate) {
        if (sampleRate != 0) {
            // Convert samples per second to cpu steps per sample
            this.apu.sampleRate = CPUFrequency / sampleRate;
            // Initialize filters
            this.apu.filterChain = new FilterChain(
                HighPassFilter(cast(float)sampleRate, 90),
                HighPassFilter(cast(float)sampleRate, 440),
                LowPassFilter(cast(float)sampleRate, 14000)
            );
        } else {
            this.apu.filterChain = null;
        }
    }

    void saveState(string fileName) {
        string[string] state = ["version": "1"];

        this.save(state);

        auto stateText = to!string(state);

        auto data = std.zlib.compress(cast(void[])stateText);

        write(fileName, data);
    }

    void loadState(string fileName) {
        auto stateData = read(fileName);

        stateData = cast(ubyte[])std.zlib.uncompress(cast(void[])stateData);

        string[string] state = to!(string[string])(cast(string)stateData);

        load(state);
    }

    void saveBatteryBackedRam(string fileName) {
        if (!this.cartridge.battery) return;

        auto data = std.zlib.compress(cast(void[])this.cartridge.sram);

        write(fileName, data);
    }

    void loadBatteryBackedRam(string fileName) {
        if (!this.cartridge.battery) return;

        auto data = read(fileName);

        this.cartridge.sram = cast(ubyte[])std.zlib.uncompress(cast(void[])data);
    }

    private:
        void save(string[string] state) {
            state["console.ram"] = Base64.encode(this.ram);

            this.cpu.save(state);
            this.apu.save(state);
            this.ppu.save(state);
            this.cartridge.save(state);
            this.mapper.save(state);
        }

        void load(string[string] state) {
            this.ram = Base64.decode(state["console.ram"]);

            this.cpu.load(state);
            this.apu.load(state);
            this.ppu.load(state);
            this.cartridge.load(state);
            this.mapper.load(state);
        }
}
