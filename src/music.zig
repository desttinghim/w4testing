const w4 = @import("wasm4.zig");
const std = @import("std");

pub const Flag = struct {
    pub const Pulse1: u8 = w4.TONE_PULSE1;
    pub const Pulse2: u8 = w4.TONE_PULSE2;
    pub const Triangle: u8 = w4.TONE_TRIANGLE;
    pub const Noise: u8 = w4.TONE_NOISE;
    pub const Mode1: u8 = w4.TONE_MODE1;
    pub const Mode2: u8 = w4.TONE_MODE2;
    pub const Mode3: u8 = w4.TONE_MODE3;
    pub const Mode4: u8 = w4.TONE_MODE4;
};
pub const Event = union(enum) {
    rest: void,
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
    song: []const Event = &[_]Event{},
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
    flags: u8 = w4.TONE_PULSE1 | w4.TONE_MODE2,
    /// Bit Format:
    /// a = attack, d = decay, r = release, s = sustain
    /// aaaaaaaa dddddddd rrrrrrrr ssssssss
    duration: u32 = 0,
    /// Values can range from 0 to 100
    volume: u8 = 50,
    /// If set, used for note slide
    freq: ?u16 = null,

    pub fn init() @This() {
        return @This(){
            // .song = song,
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

    pub fn playSong(this: *@This(), song: []const Event) void {
        this.reset();
        this.song = song;
    }

    pub fn update(this: *@This()) void {
        // Increment counter at end of function
        defer this.counter += 1;
        // Stop once the end of the song is reached
        if (this.cursor >= this.song.len) return;
        // Get current event
        var event = this.song[this.cursor];
        // Wait to play note until current note finishes
        if (event == .note and this.counter < this.next) return;
        while (this.next <= this.counter) {
            event = this.song[this.cursor];
            switch (event) {
                .flag => |flag| {
                    // w4.trace("flag");
                    this.flags = flag;
                },
                .ad => |ad| {
                    // w4.trace("ad");
                    this.duration &= 0x0000FFFF; // clear bits
                    this.duration |= @intCast(u32, ad.attack) << 24;
                    this.duration |= @intCast(u32, ad.decay) << 16;
                },
                .sr => |sr| {
                    // w4.trace("sr");
                    this.duration &= 0xFFFF0000; // clear bits
                    this.duration |= @intCast(u32, sr.release) << 8;
                    this.duration |= @intCast(u32, sr.sustain);
                },
                .vol => |vol| this.volume = vol,
                .slide => |freq| this.freq = freq,
                .rest => {
                    // w4.trace("rest");
                    this.next = this.counter + this.duration;
                },
                .note => |note| {
                    // w4.trace("note");
                    var freq = if (this.freq) |freq| freq | (note << 8) else note;
                    w4.tone(freq, this.duration, this.volume, this.flags);
                    this.next = this.counter + this.duration;
                },
            }
            this.cursor = (this.cursor + 1);
        }
    }
};
