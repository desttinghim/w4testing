const w4 = @import("wasm4.zig");

// Inspired by https://github.com/thedavesims/Wormhole/blob/main/src/music.c
const freqs = [_]u16{ 61, 93, 129, 149, 191, 240, 293 };
const notes = [_]u8{ 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 3, 0, 1, 6, 5, 4, 3, 2, 1, 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 3, 0, 1, 6, 5, 4, 3, 2, 1 };

pub const Music = struct {
    notes: []const u8,
    counter: u32,
    current_note: u32,

    pub fn new() @This() {
        return @This(){
            .notes = &notes,
            .counter = 0,
            .current_note = 0,
        };
    }

    /// Returns the updated beat
    pub fn update(this: *@This()) void {
        this.counter += 1;

        if (this.counter % 80 == 0) {
            // every 8 beats
            w4.tone(500, 2 | (20 << 8), 80, w4.TONE_NOISE);
        } else if (this.counter % 40 == 0) {
            // every 4 beats
            w4.tone(250, 2 | (20 << 8), 80, w4.TONE_NOISE);
        }

        if (this.counter % 10 == 0) {
            // every beat
            var freq = freqs[this.notes[this.current_note]];
            w4.tone(freq, 9 | (2 << 10), 100, w4.TONE_PULSE1);

            this.current_note += 1;
            this.current_note %= 64;
        }
    }
};
