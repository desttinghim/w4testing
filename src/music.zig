const w4 = @import("wasm4.zig");
const std = @import("std");

pub const Flag = enum(u8) {
    Pulse1 = w4.TONE_PULSE1,
    Pulse2 = w4.TONE_PULSE2,
    Triangle = w4.TONE_TRIANGLE,
    Noise = w4.TONE_NOISE,
    Mode1 = w4.TONE_MODE1,
    Mode2 = w4.TONE_MODE2,
    Mode3 = w4.TONE_MODE3,
    Mode4 = w4.TONE_MODE4,
};
pub const Event = union(enum) {
    /// Sets flag register
    flag: u8,
    /// Sets attack and decay registers
    ad: struct { attack: u8, decay: u8 },
    /// Sets sustain and release registers
    sr: struct { sustain: u8, release: u8 },
    /// Sets volume register
    vol: u8,
    /// Set start freq of slide
    slide: u16,
    /// Outputs note with freq and values in register
    note: u16,
};

pub const Music = struct {
    /// List of events that define the song
    song: []const Event,
    /// Internal counter for timing
    counter: u32 = 0,
    /// Next tick to process commands at
    next: u32 = 0,
    /// Index into song
    cursor: u32 = 0,

    // Registers

    /// Bit Format:
    /// x = unused, m = mode, c = channel
    /// xxxxmmcc
    flags: u8 = 0,
    /// Bit Format:
    /// a = attack, d = decay, r = release, s = sustain
    /// aaaaaaaa dddddddd rrrrrrrr ssssssss
    duration: u32 = 0,
    /// Values can range from 0 to 100
    volume: u8 = 0,
    /// If set, used for note slide
    freq: ?u16 = null,

    pub fn init(song: []const Event) @This() {
        return @This(){
            .song = song,
        };
    }

    pub fn reset(this: *@This()) void {
        this.counter = 0;
        this.cursor = 0;
        this.next = 0;

        this.flags = 0;
        this.duration = 0;
        this.volume = 0;
        this.freq = null;
    }

    pub fn setSong(this: *@This(), song: []const Event) void {
        this.reset();
        this.song = song;
    }

    pub fn update(this: *@This()) void {
        // Increment counter at end of function
        defer this.counter += 1;
        // Get current event
        var event = this.song[this.cursor];
        // Wait to play note until current note finishes
        if (event == .note and this.counter < this.next) return;
        switch (event) {
            .flag => |flag| {
                this.flags = flag;
            },
            .ad => |ad| {
                this.duration &= 0x0000FFFF; // clear bits
                this.duration |= ad.attack << 24;
                this.duration |= ad.decay << 16;
            },
            .sr => |sr| {
                this.duration &= 0xFFFF0000; // clear bits
                this.duration |= sr.release << 8;
                this.duration |= sr.sustain;
            },
            .vol => |vol| this.volume = vol,
            .slide => |freq| this.freq = freq,
            .note => |note| {
                var freq = if (this.freq) |freq| freq | (note << 8) else note;
                w4.tone(freq, this.duration, this.volume, this.flags);
                this.next = this.counter + this.duration;
                this.cursor = (this.cursor + 1) % this.notes.len;
            },
        }
    }
};
