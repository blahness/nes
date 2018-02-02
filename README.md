
### Summary

This is an NES emulator written in D. It's a port to D from Go of github.com/fogleman/nes/. It's pure D & has no dependencies.

### Installation

Just add "nes": "~>0.1.0" or "nes" version="~>0.1.0" to the dependencies section of your dub.json or dub.sdl file.

### Usage

See github.com/blahness/nes_test/ for an example usage.

### Mappers

The following mappers have been implemented:

* NROM (0)
* MMC1 (1)
* UNROM (2)
* CNROM (3)
* MMC3 (4)
* AOROM (7)
* 255

### Known Issues

* there are some minor issues with PPU timing, but most games work OK anyway
* the APU emulation isn't quite perfect, but not far off
