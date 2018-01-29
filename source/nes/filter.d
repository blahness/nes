module nes.filter;

import std.math;

interface Filter {
    float step(float x);
}

// First order filters are defined by the following parameters.
// y[n] = B0*x[n] + B1*x[n-1] - A1*y[n-1]
class FirstOrderFilter : Filter {
    this(float b0, float b1, float a1, float prevX, float prevY) {
        this.b0 = b0;
        this.b1 = b1;
        this.a1 = a1;
        this.prevX = prevX;
        this.prevY = prevY;
    }

    float step(float x) {
        auto y = this.b0 * x + this.b1 * this.prevX - this.a1 * this.prevY;
        this.prevY = y;
        this.prevX = x;
        return y;
    }

    private:
        float b0, b1, a1, prevX, prevY;
}

class FilterChain : Filter {
    this(Filter[] filters ...) {
        this.filterChain = filters.dup;
    }

    float step(float x) {
        if (this.filterChain != null) {
            foreach (f; this.filterChain) {
                x = f.step(x);
            }
        }
        return x;
    }

    private:
        Filter[] filterChain;
}

// sampleRate: samples per second
// cutoffFreq: oscillations per second
Filter LowPassFilter(float sampleRate, float cutoffFreq) {
    auto c = sampleRate / std.math.PI / cutoffFreq;
    auto a0i = 1 / (1 + c);
    return new FirstOrderFilter(a0i, a0i, (1 - c) * a0i, 0, 0);
}

Filter HighPassFilter(float sampleRate, float cutoffFreq) {
    auto c = sampleRate / std.math.PI / cutoffFreq;
    auto a0i = 1 / (1 + c);
    return new FirstOrderFilter(c * a0i, -c * a0i, (1 - c) * a0i, 0, 0);
}
