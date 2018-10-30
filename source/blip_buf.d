/* blip_buf 1.1.0. http://www.slack.net/~ant/ */

module blip_buf;

import core.stdc.stdlib;
import core.stdc.string;

/* Library Copyright (C) 2003-2009 Shay Green. This library is free software;
you can redistribute it and/or modify it under the terms of the GNU Lesser
General Public License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version. This
library is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
details. You should have received a copy of the GNU Lesser General Public
License along with this module; if not, write to the Free Software Foundation,
Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA */


/** Maximum clock_rate/sample_rate ratio. For a given sample_rate,
clock_rate must not be greater than sample_rate*blip_max_ratio. */
enum blip_max_ratio = 1 << 20;

/** Maximum number of samples that can be generated from one time frame. */
enum blip_max_frame = 4000;

alias fixed_t = ulong;
enum pre_shift = 32;

enum time_bits = pre_shift + 20;

const fixed_t time_unit = cast(fixed_t)(1) << time_bits;

enum bass_shift  = 9; /* affects high-pass filter breakpoint frequency */
enum end_frame_extra = 2; /* allows deltas slightly after frame length */

enum half_width  = 8;
enum buf_extra   = half_width*2 + end_frame_extra;
enum phase_bits  = 5;
enum phase_count = 1 << phase_bits;
enum delta_bits  = 15;
enum delta_unit  = 1 << delta_bits;
enum frac_bits = time_bits - pre_shift;

/* We could eliminate avail and encode whole samples in offset, but that would
limit the total buffered samples to blip_max_frame. That could only be
increased by decreasing time_bits, which would reduce resample ratio accuracy.
*/

/** Sample buffer that resamples to output rate and accumulates samples
until they're read out */
struct blip_t {
	fixed_t factor;
	fixed_t offset;
	int avail;
	int size;
	int integrator;
}

alias buf_t = int;

/* probably not totally portable */
buf_t* SAMPLES(blip_t* buf) {
	return  cast(buf_t*)(buf + 1);
}

/* Arithmetic (sign-preserving) right shift */
int ARITH_SHIFT(int n, int shift) {
	return n >> shift;
}

enum max_sample = +32767;
enum min_sample = -32768;

void CLAMP(ref int n) {
	if (cast(short)n != n)
		n = ARITH_SHIFT(n, 16) ^ max_sample;
}

void check_assumptions() {
	int n;
	
	assert(int.max >= 0x7FFFFFFF && uint.max >= 0xFFFFFFFF, "int must be at least 32 bits");
	
	assert((-3 >> 1) == -2); /* right shift must preserve sign */
	
	n = max_sample * 2;
	CLAMP(n);
	assert(n == max_sample);
	
	n = min_sample * 2;
	CLAMP(n);
	assert(n == min_sample);
	
	assert(blip_max_ratio <= time_unit);
	assert(blip_max_frame <= cast(fixed_t)-1 >> time_bits);
}

blip_t* blip_new(int size) {
	blip_t* m;
	assert(size >= 0);

	m = cast(blip_t*) malloc((*m).sizeof + (size + buf_extra) * buf_t.sizeof);
	if (m) {
		m.factor = time_unit / blip_max_ratio;
		m.size   = size;
		blip_clear(m);
		check_assumptions();
	}
	return m;
}

void blip_delete(blip_t* m) {
	if (m != null) {
		/* Clear fields in case user tries to use after freeing */
		memset(m, 0, (*m).sizeof);
		free(m);
	}
}

void blip_set_rates(blip_t* m, double clock_rate, double sample_rate) {
	double factor = time_unit * sample_rate / clock_rate;
	m.factor = cast(fixed_t)factor;

	/* Fails if clock_rate exceeds maximum, relative to sample_rate */
	assert(0 <= factor - m.factor && factor - m.factor < 1);

	/* Avoid requiring math.h. Equivalent to
	m.factor = (int) ceil(factor) */
	if (m.factor < factor)
		m.factor++;

	/* At this point, factor is most likely rounded up, but could still
	have been rounded down in the floating-point calculation. */
}

void blip_clear(blip_t* m) {
	/* We could set offset to 0, factor/2, or factor-1. 0 is suitable if
	factor is rounded up. factor-1 is suitable if factor is rounded down.
	Since we don't know rounding direction, factor/2 accommodates either,
	with the slight loss of showing an error in half the time. Since for
	a 64-bit factor this is years, the halving isn't a problem. */

	m.offset     = m.factor / 2;
	m.avail      = 0;
	m.integrator = 0;
	memset(SAMPLES(m), 0, (m.size + buf_extra) * buf_t.sizeof);
}

int blip_clocks_needed(const blip_t* m, int samples) {
	fixed_t needed;

	/* Fails if buffer can't hold that many more samples */
	assert(samples >= 0 && m.avail + samples <= m.size);

	needed = cast(fixed_t) samples * time_unit;
	if (needed < m.offset)
		return 0;

	return cast(int)((needed - m.offset + m.factor - 1) / m.factor);
}

void blip_end_frame(blip_t* m, uint t) {
	fixed_t off = t * m.factor + m.offset;
	m.avail += off >> time_bits;
	m.offset = off & (time_unit - 1);

	/* Fails if buffer size was exceeded */
	assert(m.avail <= m.size);
}

int blip_samples_avail(const blip_t* m) {
	return m.avail;
}

void remove_samples(blip_t* m, int count) {
	buf_t* buf = SAMPLES(m);
	int remain = m.avail + buf_extra - count;
	m.avail -= count;

	memmove(&buf [0], &buf[count], remain * buf[0].sizeof);
	memset(&buf[remain], 0, count * buf[0].sizeof);
}

int blip_read_samples(blip_t* m, short* _out, int count, int stereo) {
	assert(count >= 0);

	if (count > m.avail)
		count = m.avail;

	if (count) {
		const int step = stereo ? 2 : 1;
		const(buf_t)* _in  = SAMPLES(m);
		const(buf_t)* end = _in + count;
		int sum = m.integrator;
		do {
			/* Eliminate fraction */
			int s = ARITH_SHIFT(sum, delta_bits);

			sum += *_in++;

			CLAMP(s);

			*_out = cast(short)s;
			_out += step;

			/* High-pass filter */
			sum -= s << (delta_bits - bass_shift);
		} while (_in != end);
		m.integrator = sum;

		remove_samples(m, count);
	}

	return count;
}

/* Sinc_Generator(0.9, 0.55, 4.5) */
const short[half_width][phase_count + 1] bl_step =
[
	[   43, -115,  350, -488, 1136, -914, 5861,21022],
	[   44, -118,  348, -473, 1076, -799, 5274,21001],
	[   45, -121,  344, -454, 1011, -677, 4706,20936],
	[   46, -122,  336, -431,  942, -549, 4156,20829],
	[   47, -123,  327, -404,  868, -418, 3629,20679],
	[   47, -122,  316, -375,  792, -285, 3124,20488],
	[   47, -120,  303, -344,  714, -151, 2644,20256],
	[   46, -117,  289, -310,  634,  -17, 2188,19985],
	[   46, -114,  273, -275,  553,  117, 1758,19675],
	[   44, -108,  255, -237,  471,  247, 1356,19327],
	[   43, -103,  237, -199,  390,  373,  981,18944],
	[   42,  -98,  218, -160,  310,  495,  633,18527],
	[   40,  -91,  198, -121,  231,  611,  314,18078],
	[   38,  -84,  178,  -81,  153,  722,   22,17599],
	[   36,  -76,  157,  -43,   80,  824, -241,17092],
	[   34,  -68,  135,   -3,    8,  919, -476,16558],
	[   32,  -61,  115,   34,  -60, 1006, -683,16001],
	[   29,  -52,   94,   70, -123, 1083, -862,15422],
	[   27,  -44,   73,  106, -184, 1152,-1015,14824],
	[   25,  -36,   53,  139, -239, 1211,-1142,14210],
	[   22,  -27,   34,  170, -290, 1261,-1244,13582],
	[   20,  -20,   16,  199, -335, 1301,-1322,12942],
	[   18,  -12,   -3,  226, -375, 1331,-1376,12293],
	[   15,   -4,  -19,  250, -410, 1351,-1408,11638],
	[   13,    3,  -35,  272, -439, 1361,-1419,10979],
	[   11,    9,  -49,  292, -464, 1362,-1410,10319],
	[    9,   16,  -63,  309, -483, 1354,-1383, 9660],
	[    7,   22,  -75,  322, -496, 1337,-1339, 9005],
	[    6,   26,  -85,  333, -504, 1312,-1280, 8355],
	[    4,   31,  -94,  341, -507, 1278,-1205, 7713],
	[    3,   35, -102,  347, -506, 1238,-1119, 7082],
	[    1,   40, -110,  350, -499, 1190,-1021, 6464],
	[    0,   43, -115,  350, -488, 1136, -914, 5861]
];

/* Shifting by pre_shift allows calculation using unsigned int rather than
possibly-wider fixed_t. On 32-bit platforms, this is likely more efficient.
And by having pre_shift 32, a 32-bit platform can easily do the shift by
simply ignoring the low half. */

void blip_add_delta(blip_t* m, uint time, int delta) {
	uint fixed = cast(uint) ((time * m.factor + m.offset) >> pre_shift);
	buf_t* _out = SAMPLES(m) + m.avail + (fixed >> frac_bits);

	const int phase_shift = frac_bits - phase_bits;
	int phase = fixed >> phase_shift & (phase_count - 1);
	const(short)* _in  = bl_step[phase].ptr;
	const(short)* rev = bl_step[phase_count - phase].ptr;

	int interp = fixed >> (phase_shift - delta_bits) & (delta_unit - 1);
	int delta2 = (delta * interp) >> delta_bits;
	delta -= delta2;

	/* Fails if buffer size was exceeded */
	assert(_out <= &SAMPLES(m) [m.size + end_frame_extra]);

	_out [0] += _in[0]*delta + _in[half_width+0]*delta2;
	_out [1] += _in[1]*delta + _in[half_width+1]*delta2;
	_out [2] += _in[2]*delta + _in[half_width+2]*delta2;
	_out [3] += _in[3]*delta + _in[half_width+3]*delta2;
	_out [4] += _in[4]*delta + _in[half_width+4]*delta2;
	_out [5] += _in[5]*delta + _in[half_width+5]*delta2;
	_out [6] += _in[6]*delta + _in[half_width+6]*delta2;
	_out [7] += _in[7]*delta + _in[half_width+7]*delta2;

	_in = rev;
	_out [ 8] += _in[7]*delta + _in[7-half_width]*delta2;
	_out [ 9] += _in[6]*delta + _in[6-half_width]*delta2;
	_out [10] += _in[5]*delta + _in[5-half_width]*delta2;
	_out [11] += _in[4]*delta + _in[4-half_width]*delta2;
	_out [12] += _in[3]*delta + _in[3-half_width]*delta2;
	_out [13] += _in[2]*delta + _in[2-half_width]*delta2;
	_out [14] += _in[1]*delta + _in[1-half_width]*delta2;
	_out [15] += _in[0]*delta + _in[0-half_width]*delta2;
}

void blip_add_delta_fast(blip_t* m, uint time, int delta) {
	uint fixed = cast(uint) ((time * m.factor + m.offset) >> pre_shift);
	buf_t* _out = SAMPLES(m) + m.avail + (fixed >> frac_bits);

	int interp = fixed >> (frac_bits - delta_bits) & (delta_unit - 1);
	int delta2 = delta * interp;

	/* Fails if buffer size was exceeded */
	assert(_out <= &SAMPLES(m)[m.size + end_frame_extra]);

	_out [7] += delta * delta_unit - delta2;
	_out [8] += delta2;
}
