const w4 = @import("wasm4.zig");
const std = @import("std");

const notes = [_]u8{ 60, 63, 60, 60 } ** 16;
const Event = struct {
    note: u8, // midi note
    duration: u8, // duration, fraction of a bar
};
const events = [_]Event{
    // 1
    .{ .note = cton(3, 'c'), .duration = 4 },
    .{ .note = cton(3, 'c'), .duration = 4 },
    .{ .note = cton(3, 'g'), .duration = 4 },
    .{ .note = cton(3, 'g'), .duration = 4 },
    // 2
    .{ .note = cton(3, 'a'), .duration = 4 },
    .{ .note = cton(3, 'a'), .duration = 4 },
    .{ .note = cton(3, 'g'), .duration = 2 },
    // 3
    .{ .note = cton(3, 'f'), .duration = 4 },
    .{ .note = cton(3, 'f'), .duration = 4 },
    .{ .note = cton(3, 'e'), .duration = 4 },
    .{ .note = cton(3, 'e'), .duration = 4 },
    // 4
    .{ .note = cton(3, 'd'), .duration = 4 },
    .{ .note = cton(3, 'd'), .duration = 4 },
    .{ .note = cton(3, 'c'), .duration = 2 },
    // 5
    .{ .note = cton(3, 'g'), .duration = 4 },
    .{ .note = cton(3, 'g'), .duration = 4 },
    .{ .note = cton(3, 'f'), .duration = 4 },
    .{ .note = cton(3, 'f'), .duration = 4 },
    // 6
    .{ .note = cton(3, 'e'), .duration = 4 },
    .{ .note = cton(3, 'e'), .duration = 4 },
    .{ .note = cton(3, 'd'), .duration = 2 },
    // 7
    .{ .note = cton(3, 'g'), .duration = 4 },
    .{ .note = cton(3, 'g'), .duration = 4 },
    .{ .note = cton(3, 'f'), .duration = 4 },
    .{ .note = cton(3, 'f'), .duration = 4 },
    // 8
    .{ .note = cton(3, 'e'), .duration = 4 },
    .{ .note = cton(3, 'e'), .duration = 4 },
    .{ .note = cton(3, 'd'), .duration = 2 },
    // 9
    .{ .note = cton(3, 'c'), .duration = 4 },
    .{ .note = cton(3, 'c'), .duration = 4 },
    .{ .note = cton(3, 'g'), .duration = 4 },
    .{ .note = cton(3, 'g'), .duration = 4 },
    // 10
    .{ .note = cton(3, 'a'), .duration = 4 },
    .{ .note = cton(3, 'a'), .duration = 4 },
    .{ .note = cton(3, 'g'), .duration = 2 },
    // 11
    .{ .note = cton(3, 'f'), .duration = 4 },
    .{ .note = cton(3, 'f'), .duration = 4 },
    .{ .note = cton(3, 'e'), .duration = 4 },
    .{ .note = cton(3, 'e'), .duration = 4 },
    // 12
    .{ .note = cton(3, 'd'), .duration = 4 },
    .{ .note = cton(3, 'd'), .duration = 4 },
    .{ .note = cton(3, 'c'), .duration = 2 },
};

// octave
fn octave(o: u8) u8 {
    return switch (o) {
        0 => 24,
        1 => 36,
        2 => 48,
        3 => 60,
        4 => 72,
        5 => 84,
        6 => 96,
        7 => 108,
        8 => 120,
        else => unreachable,
    };
}

// character to note
fn cton(oct: u8, char: u8) u8 {
    const n: u8 = switch (char) {
        'c' => 0,
        'd' => 2,
        'e' => 4,
        'f' => 5,
        'g' => 7,
        'a' => 9,
        'b' => 11,
        else => unreachable,
    };
    return octave(oct) + n;
}

// note to frequency
fn ntof(note: u8) u16 {
    const a = 440.0;
    const n = @intToFloat(f32, note);
    return @floatToInt(u16, (a / 32.0) * std.math.pow(f32, 2.0, ((n - 9) / 12.0)));
}

fn ticks(duration: u8) u32 {
    const time = 4;
    const bpm = 120;
    const bps = bpm / 60;
    const fps = 60;
    const fpb = fps / bps;
    return (fpb * time) / duration;
}

pub const Music = struct {
    notes: []const Event,
    counter: u32,
    cursor: u32,
    next: u32,

    pub fn new() @This() {
        return @This(){
            .notes = &events,
            .counter = 0,
            .cursor = 0,
            .next = 0,
        };
    }

    pub fn update(this: *@This()) void {
        if (this.counter >= this.next) {
            var event = this.notes[this.cursor];
            var freq = ntof(event.note);
            var length: u32 = ticks(event.duration);
            w4.tone(freq, 9 | (length << 8), 10, w4.TONE_PULSE1);
            this.next = this.counter + length;
            this.cursor = (this.cursor + 1) % this.notes.len;
        }

        this.counter += 1;
    }
};
