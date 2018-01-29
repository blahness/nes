module nes.controller;

enum {
    ButtonA,
    ButtonB,
    ButtonSelect,
    ButtonStart,
    ButtonUp,
    ButtonDown,
    ButtonLeft,
    ButtonRight
}

class Controller {

    void setButtons(bool[8] buttons) {
        this.buttons = buttons;
    }

    ubyte read() {
        ubyte value;
        if (this.index < 8 && this.buttons[this.index]) {
            value = 1;
        }
        this.index++;
        if ((this.strobe & 1) == 1) {
            this.index = 0;
        }
        return value;
    }

    void write(ubyte value) {
        this.strobe = value;
        if ((this.strobe & 1) == 1) {
            this.index = 0;
        }
    }

    private:
        bool[8] buttons;
        ubyte index;
        ubyte strobe;
}
