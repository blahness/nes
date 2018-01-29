module nes.image;

import std.algorithm;

import nes.color;

struct Point {
    int x, y;
}

struct Rectangle {
    Point min, max;

    int dx() {
        return this.max.x - this.min.x;
    }

    int dy() {
        return this.max.y - this.min.y;
    }
}

// PointIn reports whether p is in r.
bool PointIn(Point p, Rectangle r) {
    return r.min.x <= p.x && p.x < r.max.x &&
        r.min.y <= p.y && p.y < r.max.y;
}

class ImageRGBA {
    ubyte[] pix;
    int stride;
    Rectangle rect;

    this(Rectangle r) {
        auto w = r.dx();
        auto h = r.dy();
        
        this.pix = new ubyte[4 * w * h];
        this.stride = 4 * w;
        this.rect = r;
    }

    // PixOffset returns the index of the first element of Pix that corresponds to
    // the pixel at (x, y).
    int pixOffset(int x, int y) {
        return (y - this.rect.min.y) * this.stride + (x - this.rect.min.x) * 4;
    }

    void setRGBA(int x, int y, RGBA c) {
        if (!PointIn(Point(x, y), this.rect)) {
            return;
        }

        auto i = this.pixOffset(x, y);
        this.pix[i + 0] = c.r;
        this.pix[i + 1] = c.g;
        this.pix[i + 2] = c.b;
        this.pix[i + 3] = c.a;
    }
}

Rectangle Rect(int x0, int y0, int x1, int y1) {
    if (x0 > x1) {
        swap(x0, x1);
    }

    if (y0 > y1) {
        swap(y0, y1);
    }

    return Rectangle(Point(x0, y0), Point(x1, y1));
}
