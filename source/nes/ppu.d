module nes.ppu;

import std.algorithm;
import std.conv;
import std.stdio;

import nes.console;
import nes.image;
import nes.memory;
import nes.palette;

struct SpritePixel {
    ubyte index;
    ubyte color;
}

class PPU : PPUMemory {
    this(Console console) {
        super(console);
        this.console = console;
        this.front = new ImageRGBA(Rect(0, 0, 256, 240));
        this.back = new ImageRGBA(Rect(0, 0, 256, 240));
        this.reset();
    }

    void reset() {
        this.cycle = 340;
        this.scanLine = 240;
        this.frame = 0;
        this.writeControl(0);
        this.writeMask(0);
        this.writeOAMAddress(0);
    }

    // Step executes a single PPU cycle
    void step() {
        this.tick();

        auto renderingEnabled = this.flagShowBackground != 0 || this.flagShowSprites != 0;
        auto preLine = this.scanLine == 261;
        auto visibleLine = this.scanLine < 240;
        // auto postLine = this.scanLine == 240;
        auto renderLine = preLine || visibleLine;
        auto preFetchCycle = this.cycle >= 321 && this.cycle <= 336;
        auto visibleCycle = this.cycle >= 1 && this.cycle <= 256;
        auto fetchCycle = preFetchCycle || visibleCycle;

        // background logic
        if (renderingEnabled) {
            if (visibleLine && visibleCycle) {
                this.renderPixel();
            }
            if (renderLine && fetchCycle) {
                this.tileData <<= 4;
                switch (this.cycle % 8) {
                    case 1:
                        this.fetchNameTableByte();
                        break;
                    case 3:
                        this.fetchAttributeTableByte();
                        break;
                    case 5:
                        this.fetchLowTileByte();
                        break;
                    case 7:
                        this.fetchHighTileByte();
                        break;
                    case 0:
                        this.storeTileData();
                        break;
                    default:
                        break;
                }
            }
            if (preLine && this.cycle >= 280 && this.cycle <= 304) {
                this.copyY();
            }
            if (renderLine) {
                if (fetchCycle && this.cycle % 8 == 0) {
                    this.incrementX();
                }
                if (this.cycle == 256) {
                    this.incrementY();
                }
                if (this.cycle == 257) {
                    this.copyX();
                }
            }
        }

        // sprite logic
        if (renderingEnabled) {
            if (this.cycle == 257) {
                if (visibleLine) {
                    this.evaluateSprites();
                } else {
                    this.spriteCount = 0;
                }
            }
        }

        // vblank logic
        if (this.scanLine == 241 && this.cycle == 1) {
            this.setVerticalBlank();
        }
        if (preLine && this.cycle == 1) {
            this.clearVerticalBlank();
            this.flagSpriteZeroHit = 0;
            this.flagSpriteOverflow = 0;
        }
    }

    ubyte readRegister(ushort address) {
        switch (address) {
            case 0x2002:
                return this.readStatus();
            case 0x2004:
                return this.readOAMData();
            case 0x2007:
                return this.readData();
            default:
                break;
        }

        return 0;
    }

    void writeRegister(ushort address, ubyte value) {
        this.register = value;

        switch (address) {
            case 0x2000:
                this.writeControl(value);
                break;
            case 0x2001:
                this.writeMask(value);
                break;
            case 0x2003:
                this.writeOAMAddress(value);
                break;
            case 0x2004:
                this.writeOAMData(value);
                break;
            case 0x2005:
                this.writeScroll(value);
                break;
            case 0x2006:
                this.writeAddress(value);
                break;
            case 0x2007:
                this.writeData(value);
                break;
            case 0x4014:
                this.writeDMA(value);
                break;
            default:
                break;
        }
    }

    ubyte readPalette(ushort address) {
        if (address >= 16 && address % 4 == 0) {
            address -= 16;
        }

        return this.paletteData[address];
    }

    void writePalette(ushort address, ubyte value) {
        if (address >= 16 && address % 4 == 0) {
            address -= 16;
        }

        this.paletteData[address] = value;
    }

    void save(string[string] state) {
        state["ppu.cycle"] = to!string(this.cycle);
        state["ppu.scanLine"] = to!string(this.scanLine);
        state["ppu.frame"] = to!string(this.frame);
        state["ppu.paletteData"] = to!string(this.paletteData);
        state["ppu.nameTableData"] = to!string(this.nameTableData);
        state["ppu.oamData"] = to!string(this.oamData);
        state["ppu.v"] = to!string(this.v);
        state["ppu.t"] = to!string(this.t);
        state["ppu.x"] = to!string(this.x);
        state["ppu.w"] = to!string(this.w);
        state["ppu.f"] = to!string(this.f);
        state["ppu.register"] = to!string(this.register);
        state["ppu.nmiOccurred"] = to!string(this.nmiOccurred);
        state["ppu.nmiOutput"] = to!string(this.nmiOutput);
        state["ppu.nmiPrevious"] = to!string(this.nmiPrevious);
        state["ppu.nmiDelay"] = to!string(this.nmiDelay);
        state["ppu.nameTableByte"] = to!string(this.nameTableByte);
        state["ppu.attributeTableByte"] = to!string(this.attributeTableByte);
        state["ppu.lowTileByte"] = to!string(this.lowTileByte);
        state["ppu.highTileByte"] = to!string(this.highTileByte);
        state["ppu.tileData"] = to!string(this.tileData);
        state["ppu.spriteCount"] = to!string(this.spriteCount);
        state["ppu.spritePatterns"] = to!string(this.spritePatterns);
        state["ppu.spritePositions"] = to!string(this.spritePositions);
        state["ppu.spritePriorities"] = to!string(this.spritePriorities);
        state["ppu.spriteIndexes"] = to!string(this.spriteIndexes);
        state["ppu.flagNameTable"] = to!string(this.flagNameTable);
        state["ppu.flagIncrement"] = to!string(this.flagIncrement);
        state["ppu.flagSpriteTable"] = to!string(this.flagSpriteTable);
        state["ppu.flagBackgroundTable"] = to!string(this.flagBackgroundTable);
        state["ppu.flagSpriteSize"] = to!string(this.flagSpriteSize);
        state["ppu.flagMasterSlave"] = to!string(this.flagMasterSlave);
        state["ppu.flagGrayscale"] = to!string(this.flagGrayscale);
        state["ppu.flagShowLeftBackground"] = to!string(this.flagShowLeftBackground);
        state["ppu.flagShowLeftSprites"] = to!string(this.flagShowLeftSprites);
        state["ppu.flagShowBackground"] = to!string(this.flagShowBackground);
        state["ppu.flagShowSprites"] = to!string(this.flagShowSprites);
        state["ppu.flagRedTint"] = to!string(this.flagRedTint);
        state["ppu.flagGreenTint"] = to!string(this.flagGreenTint);
        state["ppu.flagBlueTint"] = to!string(this.flagBlueTint);
        state["ppu.flagSpriteZeroHit"] = to!string(this.flagSpriteZeroHit);
        state["ppu.flagSpriteOverflow"] = to!string(this.flagSpriteOverflow);
        state["ppu.oamAddress"] = to!string(this.oamAddress);
        state["ppu.bufferedData"] = to!string(this.bufferedData);
    }

    void load(string[string] state) {
        this.cycle = to!int(state["ppu.cycle"]);
        this.scanLine = to!int(state["ppu.scanLine"]);
        this.frame = to!ulong(state["ppu.frame"]);
        this.paletteData = to!(ubyte[32])(state["ppu.paletteData"]);
        this.nameTableData = to!(ubyte[2048])(state["ppu.nameTableData"]);
        this.oamData = to!(ubyte[256])(state["ppu.oamData"]);
        this.v = to!ushort(state["ppu.v"]);
        this.t = to!ushort(state["ppu.t"]);
        this.x = to!ubyte(state["ppu.x"]);
        this.w = to!ubyte(state["ppu.w"]);
        this.f = to!ubyte(state["ppu.f"]);
        this.register = to!ubyte(state["ppu.register"]);
        this.nmiOccurred = to!bool(state["ppu.nmiOccurred"]);
        this.nmiOutput = to!bool(state["ppu.nmiOutput"]);
        this.nmiPrevious = to!bool(state["ppu.nmiPrevious"]);
        this.nmiDelay = to!ubyte(state["ppu.nmiDelay"]);
        this.nameTableByte = to!ubyte(state["ppu.nameTableByte"]);
        this.attributeTableByte = to!ubyte(state["ppu.attributeTableByte"]);
        this.lowTileByte = to!ubyte(state["ppu.lowTileByte"]);
        this.highTileByte = to!ubyte(state["ppu.highTileByte"]);
        this.tileData = to!ulong(state["ppu.tileData"]);
        this.spriteCount = to!int(state["ppu.spriteCount"]);
        this.spritePatterns = to!(uint[8])(state["ppu.spritePatterns"]);
        this.spritePositions = to!(ubyte[8])(state["ppu.spritePositions"]);
        this.spritePriorities = to!(ubyte[8])(state["ppu.spritePriorities"]);
        this.spriteIndexes = to!(ubyte[8])(state["ppu.spriteIndexes"]);
        this.flagNameTable = to!ubyte(state["ppu.flagNameTable"]);
        this.flagIncrement = to!ubyte(state["ppu.flagIncrement"]);
        this.flagSpriteTable = to!ubyte(state["ppu.flagSpriteTable"]);
        this.flagBackgroundTable = to!ubyte(state["ppu.flagBackgroundTable"]);
        this.flagSpriteSize = to!ubyte(state["ppu.flagSpriteSize"]);
        this.flagMasterSlave = to!ubyte(state["ppu.flagMasterSlave"]);
        this.flagGrayscale = to!ubyte(state["ppu.flagGrayscale"]);
        this.flagShowLeftBackground = to!ubyte(state["ppu.flagShowLeftBackground"]);
        this.flagShowLeftSprites = to!ubyte(state["ppu.flagShowLeftSprites"]);
        this.flagShowBackground = to!ubyte(state["ppu.flagShowBackground"]);
        this.flagShowSprites = to!ubyte(state["ppu.flagShowSprites"]);
        this.flagRedTint = to!ubyte(state["ppu.flagRedTint"]);
        this.flagGreenTint = to!ubyte(state["ppu.flagGreenTint"]);
        this.flagBlueTint = to!ubyte(state["ppu.flagBlueTint"]);
        this.flagSpriteZeroHit = to!ubyte(state["ppu.flagSpriteZeroHit"]);
        this.flagSpriteOverflow = to!ubyte(state["ppu.flagSpriteOverflow"]);
        this.oamAddress = to!ubyte(state["ppu.oamAddress"]);
        this.bufferedData = to!ubyte(state["ppu.bufferedData"]);
    }

    package:
        Console     console;
        ubyte[2048] nameTableData;
        ImageRGBA   front;
        ImageRGBA   back;

        int   cycle;    // 0-340
        int   scanLine; // 0-261, 0-239=visible, 240=post, 241-260=vblank, 261=pre
        ulong frame;    // frame counter

        // storage variables
        ubyte[32]  paletteData;
        ubyte[256] oamData;

        // PPU registers
        ushort v; // current vram address (15 bit)
        ushort t; // temporary vram address (15 bit)
        ubyte  x; // fine x scroll (3 bit)
        ubyte  w; // write toggle (1 bit)
        ubyte  f; // even/odd frame flag (1 bit)

        ubyte register;

        // NMI flags
        bool  nmiOccurred;
        bool  nmiOutput;
        bool  nmiPrevious;
        ubyte nmiDelay;

        // background temporary variables
        ubyte nameTableByte;
        ubyte attributeTableByte;
        ubyte lowTileByte;
        ubyte highTileByte;
        ulong tileData;

        // sprite temporary variables
        int      spriteCount;
        uint[8]  spritePatterns;
        ubyte[8] spritePositions;
        ubyte[8] spritePriorities;
        ubyte[8] spriteIndexes;

        // $2000 PPUCTRL
        ubyte flagNameTable; // 0: $2000; 1: $2400; 2: $2800; 3: $2C00
        ubyte flagIncrement; // 0: add 1; 1: add 32
        ubyte flagSpriteTable; // 0: $0000; 1: $1000; ignored in 8x16 mode
        ubyte flagBackgroundTable; // 0: $0000; 1: $1000
        ubyte flagSpriteSize; // 0: 8x8; 1: 8x16
        ubyte flagMasterSlave; // 0: read EXT; 1: write EXT

        // $2001 PPUMASK
        ubyte flagShowBackground; // 0: hide; 1: show
        ubyte flagShowSprites; // 0: hide; 1: show
        ubyte flagGrayscale; // 0: color; 1: grayscale
        ubyte flagShowLeftBackground; // 0: hide; 1: show
        ubyte flagShowLeftSprites; // 0: hide; 1: show
        ubyte flagRedTint; // 0: normal; 1: emphasized
        ubyte flagGreenTint; // 0: normal; 1: emphasized
        ubyte flagBlueTint; // 0: normal; 1: emphasized

        // $2002 PPUSTATUS
        ubyte flagSpriteZeroHit;
        ubyte flagSpriteOverflow;

        // $2003 OAMADDR
        ubyte oamAddress;

        // $2007 PPUDATA
        ubyte bufferedData; // for buffered reads

    private:
        // $2000: PPUCTRL
        void writeControl(ubyte value) {
            this.flagNameTable = (value >> 0) & 3;
            this.flagIncrement = (value >> 2) & 1;
            this.flagSpriteTable = (value >> 3) & 1;
            this.flagBackgroundTable = (value >> 4) & 1;
            this.flagSpriteSize = (value >> 5) & 1;
            this.flagMasterSlave = (value >> 6) & 1;
            this.nmiOutput = ((value >> 7) & 1) == 1;
            this.nmiChange();
            // t: ....BA.. ........ = d: ......BA
            this.t = (this.t & 0xF3FF) | ((cast(ushort)(value) & 0x03) << 10);
        }

        // $2001: PPUMASK
        void writeMask(ubyte value) {
            this.flagGrayscale = (value >> 0) & 1;
            this.flagShowLeftBackground = (value >> 1) & 1;
            this.flagShowLeftSprites = (value >> 2) & 1;
            this.flagShowBackground = (value >> 3) & 1;
            this.flagShowSprites = (value >> 4) & 1;
            this.flagRedTint = (value >> 5) & 1;
            this.flagGreenTint = (value >> 6) & 1;
            this.flagBlueTint = (value >> 7) & 1;
        }

        // $2002: PPUSTATUS
        ubyte readStatus() {
            ubyte result = this.register & 0x1F;
            result |= this.flagSpriteOverflow << 5;
            result |= this.flagSpriteZeroHit << 6;
            if (this.nmiOccurred) {
                result |= 1 << 7;
            }
            this.nmiOccurred = false;
            this.nmiChange();
            // w:                   = 0
            this.w = 0;
            return result;
        }

        // $2003: OAMADDR
        void writeOAMAddress(ubyte value) {
            this.oamAddress = value;
        }

        // $2004: OAMDATA (read)
        ubyte readOAMData() {
            return this.oamData[this.oamAddress];
        }

        // $2004: OAMDATA (write)
        void writeOAMData(ubyte value) {
            this.oamData[this.oamAddress] = value;
            this.oamAddress++;
        }

        // $2005: PPUSCROLL
        void writeScroll(ubyte value) {
            if (this.w == 0) {
                // t: ........ ...HGFED = d: HGFED...
                // x:               CBA = d: .....CBA
                // w:                   = 1
                this.t = (this.t & 0xFFE0) | (cast(ushort)value >> 3);
                this.x = value & 0x07;
                this.w = 1;
            } else {
                // t: .CBA..HG FED..... = d: HGFEDCBA
                // w:                   = 0
                this.t = (this.t & 0x8FFF) | ((cast(ushort)value & 0x07) << 12);
                this.t = (this.t & 0xFC1F) | ((cast(ushort)value & 0xF8) << 2);
                this.w = 0;
            }
        }

        // $2006: PPUADDR
        void writeAddress(ubyte value) {
            if (this.w == 0) {
                // t: ..FEDCBA ........ = d: ..FEDCBA
                // t: .X...... ........ = 0
                // w:                   = 1
                this.t = (this.t & 0x80FF) | ((cast(ushort)value & 0x3F) << 8);
                this.w = 1;
            } else {
                // t: ........ HGFEDCBA = d: HGFEDCBA
                // v                    = t
                // w:                   = 0
                this.t = (this.t & 0xFF00) | cast(ushort)value;
                this.v = this.t;
                this.w = 0;
            }
        }

        // $2007: PPUDATA (read)
        ubyte readData() {
            auto value = this.read(this.v);
            // emulate buffered reads
            if (this.v % 0x4000 < 0x3F00) {
                auto buffered = this.bufferedData;
                this.bufferedData = value;
                value = buffered;
            } else {
                this.bufferedData = this.read(cast(ushort)(this.v - 0x1000));
            }
            // increment address
            if (this.flagIncrement == 0) {
                this.v += 1;
            } else {
                this.v += 32;
            }
            return value;
        }

        // $2007: PPUDATA (write)
        void writeData(ubyte value) {
            this.write(this.v, value);
            if (this.flagIncrement == 0) {
                this.v += 1;
            } else {
                this.v += 32;
            }
        }

        // $4014: OAMDMA
        void writeDMA(ubyte value) {
            auto cpu = this.console.cpu;
            ushort address = cast(ushort)value << 8;
            foreach (_; 0 .. 256) {
                this.oamData[this.oamAddress] = cpu.read(address);
                this.oamAddress++;
                address++;
            }
            cpu.stall += 513;
            if (cpu.cycles % 2 == 1) {
                cpu.stall++;
            }
        }

        // NTSC Timing Helper Functions

        void incrementX() {
            // increment hori(v)
            // if coarse X == 31
            if ((this.v & 0x001F) == 31) {
                // coarse X = 0
                this.v &= 0xFFE0;
                // switch horizontal nametable
                this.v ^= 0x0400;
            } else {
                // increment coarse X
                this.v++;
            }
        }

        void incrementY() {
            // increment vert(v)
            // if fine Y < 7
            if ((this.v & 0x7000) != 0x7000) {
                // increment fine Y
                this.v += 0x1000;
            } else {
                // fine Y = 0
                this.v &= 0x8FFF;
                // let y = coarse Y
                ushort y = (this.v & 0x03E0) >> 5;
                if (y == 29) {
                    // coarse Y = 0
                    y = 0;
                    // switch vertical nametable
                    this.v ^= 0x0800;
                } else if (y == 31) {
                    // coarse Y = 0, nametable not switched
                    y = 0;
                } else {
                    // increment coarse Y
                    y++;
                }
                // put coarse Y back into v
                this.v = cast(ushort)((this.v & 0xFC1F) | (y << 5));
            }
        }

        void copyX() {
            // hori(v) = hori(t)
            // v: .....F.. ...EDCBA = t: .....F.. ...EDCBA
            this.v = (this.v & 0xFBE0) | (this.t & 0x041F);
        }

        void copyY() {
            // vert(v) = vert(t)
            // v: .IHGF.ED CBA..... = t: .IHGF.ED CBA.....
            this.v = (this.v & 0x841F) | (this.t & 0x7BE0);
        }

        void nmiChange() {
            auto nmi = this.nmiOutput && this.nmiOccurred;
            if (nmi && !this.nmiPrevious) {
                // TODO: this fixes some games but the delay shouldn't have to be so
                // long, so the timings are off somewhere
                this.nmiDelay = 15;
            }
            this.nmiPrevious = nmi;
        }

        void setVerticalBlank() {
            swap(this.front, this.back);
            this.nmiOccurred = true;
            this.nmiChange();
        }

        void clearVerticalBlank() {
            this.nmiOccurred = false;
            this.nmiChange();
        }

        void fetchNameTableByte() {
            auto v = this.v;
            ushort address = 0x2000 | (v & 0x0FFF);
            this.nameTableByte = this.read(address);
        }

        void fetchAttributeTableByte() {
            auto v = this.v;
            ushort address = 0x23C0 | (v & 0x0C00) | ((v >> 4) & 0x38) | ((v >> 2) & 0x07);
            ubyte shift = ((v >> 4) & 4) | (v & 2);
            this.attributeTableByte = ((this.read(address) >> shift) & 3) << 2;
        }

        void fetchLowTileByte() {
            ushort fineY = (this.v >> 12) & 7; // Port: Maybe should be ubyte
            auto table = this.flagBackgroundTable;
            auto tile = this.nameTableByte;
            ushort address = cast(ushort)(0x1000 * cast(ushort)table + cast(ushort)tile * 16 + fineY);
            this.lowTileByte = this.read(address);
        }

        void fetchHighTileByte() {
            ushort fineY = (this.v >> 12) & 7; // Port: Maybe should be ubyte
            auto table = this.flagBackgroundTable;
            auto tile = this.nameTableByte;
            ushort address = cast(ushort)(0x1000 * cast(ushort)table + cast(ushort)tile * 16 + fineY);
            this.highTileByte = this.read(cast(ushort)(address + 8));
        }

        void storeTileData() {
            uint data;
            foreach (_; 0 .. 8) {
                auto a = this.attributeTableByte;
                ubyte p1 = (this.lowTileByte & 0x80) >> 7;
                ubyte p2 = (this.highTileByte & 0x80) >> 6;
                this.lowTileByte <<= 1;
                this.highTileByte <<= 1;
                data <<= 4;
                data |= cast(uint)(a | p1 | p2);
            }
            this.tileData |= cast(ulong)data;
        }

        uint fetchTileData() {
            return cast(uint)(this.tileData >> 32);
        }

        ubyte backgroundPixel() {
            if (this.flagShowBackground == 0) {
                return 0;
            }
            uint data = this.fetchTileData() >> ((7 - this.x) * 4);
            return cast(ubyte)(data & 0x0F);
        }

        SpritePixel spritePixel() {
            if (this.flagShowSprites == 0) {
                return SpritePixel(0, 0);
            }
            foreach (i; 0 .. this.spriteCount) {
                int offset = (this.cycle - 1) - cast(int)this.spritePositions[i];
                if (offset < 0 || offset > 7) {
                    continue;
                }
                offset = 7 - offset;
                ubyte color = cast(ubyte)((this.spritePatterns[i] >> cast(ubyte)(offset * 4)) & 0x0F);
                if (color % 4 == 0) {
                    continue;
                }
                return SpritePixel(cast(ubyte)i, color);
            }
            return SpritePixel(0, 0);
        }

        void renderPixel() {
            auto x = this.cycle - 1;
            auto y = this.scanLine;
            auto background = this.backgroundPixel();
            auto sp = this.spritePixel();
            auto i = sp.index;
            auto sprite = sp.color;
            if (x < 8 && this.flagShowLeftBackground == 0) {
                background = 0;
            }
            if (x < 8 && this.flagShowLeftSprites == 0) {
                sprite = 0;
            }
            auto b = background % 4 != 0;
            auto s = sprite % 4 != 0;
            ubyte color;
            if (!b && !s) {
                color = 0;
            } else if (!b && s) {
                color = sprite | 0x10;
            } else if (b && !s) {
                color = background;
            } else {
                if (this.spriteIndexes[i] == 0 && x < 255) {
                    this.flagSpriteZeroHit = 1;
                }
                if (this.spritePriorities[i] == 0) {
                    color = sprite | 0x10;
                } else {
                    color = background;
                }
            }
            auto c = Palette[this.readPalette(cast(ushort)color) % 64];
            this.back.setRGBA(x, y, c);
        }

        uint fetchSpritePattern(int i, int row) {
            auto tile = this.oamData[i * 4 + 1];
            auto attributes = this.oamData[i * 4 + 2];
            ushort address;
            if (this.flagSpriteSize == 0) {
                if ((attributes & 0x80) == 0x80) {
                    row = 7 - row;
                }
                auto table = this.flagSpriteTable;
                address = cast(ushort)(0x1000 * cast(ushort)table + cast(ushort)tile * 16 + cast(ushort)row);
            } else {
                if ((attributes & 0x80) == 0x80) {
                    row = 15 - row;
                }
                auto table = tile & 1;
                tile &= 0xFE;
                if (row > 7) {
                    tile++;
                    row -= 8;
                }
                address = cast(ushort)(0x1000 * cast(ushort)table + cast(ushort)tile * 16 + cast(ushort)row);
            }
            auto a = (attributes & 3) << 2;
            auto lowTileByte = this.read(address);
            auto highTileByte = this.read(cast(ushort)(address + 8));
            uint data;
            foreach (_; 0 .. 8) {
                ubyte p1, p2;
                if ((attributes & 0x40) == 0x40) {
                    p1 = (lowTileByte & 1) << 0;
                    p2 = (highTileByte & 1) << 1;
                    lowTileByte >>= 1;
                    highTileByte >>= 1;
                } else {
                    p1 = (lowTileByte & 0x80) >> 7;
                    p2 = (highTileByte & 0x80) >> 6;
                    lowTileByte <<= 1;
                    highTileByte <<= 1;
                }
                data <<= 4;
                data |= cast(uint)(a | p1 | p2);
            }
            return data;
        }

        void evaluateSprites() {
            int h;
            if (this.flagSpriteSize == 0) {
                h = 8;
            } else {
                h = 16;
            }
            auto count = 0;
            foreach (i; 0 .. 64) {
                auto y = this.oamData[i*4+0];
                auto a = this.oamData[i*4+2];
                auto x = this.oamData[i*4+3];
                auto row = this.scanLine - cast(int)y;
                if (row < 0 || row >= h) {
                    continue;
                }
                if (count < 8) {
                    this.spritePatterns[count] = this.fetchSpritePattern(i, row);
                    this.spritePositions[count] = x;
                    this.spritePriorities[count] = (a >> 5) & 1;
                    this.spriteIndexes[count] = cast(ubyte)i;
                }
                count++;
            }
            if (count > 8) {
                count = 8;
                this.flagSpriteOverflow = 1;
            }
            this.spriteCount = count;
        }

        // tick updates Cycle, ScanLine and Frame counters
        void tick() {
            if (this.nmiDelay > 0) {
                this.nmiDelay--;
                if (this.nmiDelay == 0 && this.nmiOutput && this.nmiOccurred) {
                    this.console.cpu.triggerNMI();
                }
            }

            if (this.flagShowBackground != 0 || this.flagShowSprites != 0) {
                if (this.f == 1 && this.scanLine == 261 && this.cycle == 339) {
                    this.cycle = 0;
                    this.scanLine = 0;
                    this.frame++;
                    this.f ^= 1;
                    return;
                }
            }
            this.cycle++;
            if (this.cycle > 340) {
                this.cycle = 0;
                this.scanLine++;
                if (this.scanLine > 261) {
                    this.scanLine = 0;
                    this.frame++;
                    this.f ^= 1;
                }
            }
        }
}
