module nes.mapper;

import std.format;

import nes.console;
import nes.mapper1;
import nes.mapper2;
import nes.mapper3;
import nes.mapper4;
import nes.mapper7;
import nes.mapper225;

interface Mapper {
    ubyte read(ushort address);
    void write(ushort address, ubyte value);
    void step();
    void save(string[string] state);
    void load(string[string] state);
}

class MapperException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

Mapper NewMapper(Console console) {
    auto cartridge = console.cartridge;

    switch (cartridge.mapper) {
        case 0:
            return new Mapper2(cartridge);
        case 1:
            return new Mapper1(cartridge);
        case 2:
            return new Mapper2(cartridge);
        case 3:
            return new Mapper3(cartridge);
        case 4:
            return new Mapper4(console, cartridge);
        case 7:
            return new Mapper7(cartridge);
        case 225:
            return new Mapper225(cartridge);
        default:
            throw new MapperException(format("unsupported mapper: %d", cartridge.mapper));
    }
}
