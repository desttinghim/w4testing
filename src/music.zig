const w4 = @import("wasm4.zig");
const std = @import("std");
const util = @import("util.zig");
const BoundedArray = std.BoundedArray;

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
    /// Rests for the currently set duration
    rest: struct { duration: u8 },
    /// Sets a parameter for the current cursor. Currently only used on the
    /// Pulse1 and Pulse2 channels to set the duty cycle
    param: u8,
    /// Sets attack and decay registers
    adsr: u32,
    /// Sets volume register
    vol: u8,
    /// Set start freq of slide
    slide: u16,
    /// Outputs note with freq and values in register
    note: struct { freq: u16, duration: u8 },
    /// Signifies end of part, tells cursor to go back to beginning
    end,

    const Self = @This();
    pub fn init_adsr(a: u32, d: u32, s: u32, r: u32) Self {
        return Self{ .adsr = a << 24 | d << 16 | r << 8 | s };
    }
    pub fn init_note(f: u16, dur: u32) Self {
        return Self{ .note = .{ .freq = f, .duration = @intCast(u8, dur) } };
    }
    pub fn init_rest(dur: u32) Self {
        return Self{ .rest = .{ .duration = @intCast(u8, dur) } };
    }
};

pub const ControlEvent = union(enum) {
    play: struct { channel: CursorChannel, pattern: u8 },
    wait: u16,
    goto: u16,
    end,

    pub fn init_play(channel: CursorChannel, pattern: u32) @This() {
        return @This(){ .play = .{ .channel = channel, .pattern = @intCast(u8, pattern) } };
    }
};

const CONTROL_MAX = 20;
pub const Song = BoundedArray(ControlEvent, CONTROL_MAX);

// NOTE: Numbers chosen here are mostly arbitrary. At first I was going to
// make passing a size variable at comptime possible, but I couldn't figure
// out how I could store a pointer to the song in WAE and have arbitrary
// comptime known sizes.
pub const Context = struct {
    /// The event list, maximum size of 200 events.
    events: BoundedArray(Event, EVENT_MAX),
    /// Song list
    songs: BoundedArray(Song, SONG_MAX),

    const EVENT_MAX = 255;
    const SONG_MAX = 10;

    pub fn init() !@This() {
        return @This(){
            .events = try BoundedArray(Event, EVENT_MAX).init(0),
            .songs = try BoundedArray(Song, SONG_MAX).init(0),
        };
    }
};

/// What channel each cursor corresponds to
pub const CursorChannel = enum(u8) {
    p1 = w4.TONE_PULSE1,
    p2 = w4.TONE_PULSE2,
    tri = w4.TONE_TRIANGLE,
    noise = w4.TONE_NOISE,
    any,
    none,
};

pub const WAE = struct {
    /// Pointer to the song data structure
    context: Context,
    /// Index of the current song
    song: ?u16 = null,
    /// Index into current song
    contextCursor: u16 = 0,
    /// Next frame to update contextCursor
    contextNext: u32 = 0,
    /// Internal counter for timing
    counter: u32 = 0,
    /// Next tick to process commands at, per channel
    next: [4]u32 = .{ 0, 0, 0, 0 },
    /// Indexes into song event list. Each audio channel has one
    cursor: [4]?u32 = .{ null, null, null, null },
    /// Beginning of current loop
    begin: [4]u32 = .{ 0, 0, 0, 0 },
    /// Parameter byte for each channel. Only used by
    /// PULSE1 and PULSE2 for setting duty cycle
    param: [4]u8 = .{ 0, 0, 0, 0 },
    /// Bit Format:
    /// a = attack, d = decay, r = release, s = sustain
    /// aaaaaaaa dddddddd rrrrrrrr ssssssss
    /// The duration of the note is determined by summing each of the components.
    adsr: [4]u32 = .{ 0, 0, 0, 0 },
    /// Values can range from 0 to 100. Values outside that range are undefined
    /// behavior.
    volume: [4]u8 = .{ 0, 0, 0, 0 },
    /// If this value is set, it is used as the initial frequency in a slide.
    /// It is assumed this will only be set at the beginning of a slide.
    freq: [4]?u16 = .{ 0, 0, 0, 0 },

    pub fn init(context: Context) @This() {
        return @This(){
            .context = context,
        };
    }

    /// Clear state
    pub fn reset(this: *@This()) void {
        this.song = null;
        this.contextCursor = 0;
        this.contextNext = 0;
        this.begin = .{ 0, 0, 0, 0 };
        this.counter = 0;
        this.next = .{ 0, 0, 0, 0 };
        this.cursor = .{ null, null, null, null };
        this.param = .{ 0, 0, 0, 0 };
        this.adsr = .{ 0, 0, 0, 0 };
        this.volume = .{ 0, 0, 0, 0 };
        this.freq = .{ null, null, null, null };
    }

    /// Set the song to play next
    pub fn playSong(this: *@This(), song: u16) void {
        this.reset();
        this.song = song;
    }

    const ChannelState = struct {
        begin: *u32,
        next: *u32,
        cursor: *u32,
        param: *u8,
        adsr: *u32,
        volume: *u8,
        freq: *?u16,
    };
    /// Returns pointers to every register
    fn getChannelState(this: *@This(), channel: usize) ChannelState {
        return ChannelState{
            .begin = &this.begin[channel],
            .next = &this.next[channel],
            .cursor = &this.cursor[channel].?,
            .param = &this.param[channel],
            .adsr = &this.adsr[channel],
            .volume = &this.volume[channel],
            .freq = &this.freq[channel],
        };
    }

    pub fn _controlUpdate(this: *@This()) bool {
        var songIndex = this.song orelse return false;
        var song = this.context.songs.slice()[songIndex].slice();
        var event = song[this.contextCursor];
        while (this.contextNext <= this.counter) {
            util.trace("{}", .{event});
            switch (event) {
                .play => |p| {
                    const channel = @enumToInt(p.channel);
                    this.cursor[channel] = p.pattern;
                    this.begin[channel] = p.pattern;
                },
                .wait => |w| this.contextNext = this.counter + w,
                .goto => |a| this.contextCursor = a,
                .end => {
                    this.song = null;
                    return false;
                },
            }
            if (event != .goto) this.contextCursor += 1;
            event = song[this.contextCursor];
        }
        return true;
    }

    /// Call once per frame. Frames are expected to be at 60 fps.
    pub fn update(this: *@This()) void {
        if (!this._controlUpdate()) return;
        // Increment counter at end of function
        defer this.counter += 1;
        // Only attempt to update if we have a song
        const song = this.context;
        const events = song.events.constSlice();
        for (this.cursor) |c, i| {
            if (c == null) continue;
            var state = this.getChannelState(i);
            // Stop once the end of the song is reached
            if (state.cursor.* >= song.events.len) continue;
            // Get current event
            var event = events[state.cursor.*];
            // Wait to play note until current note finishes
            if (event == .note and this.counter < state.next.*) continue;
            while (state.next.* <= this.counter) {
                event = events[state.cursor.*];
                switch (event) {
                    .end => {
                        state.cursor.* = state.begin.*;
                    },
                    .param => |param| {
                        // w4.trace("param");
                        state.param.* = param;
                    },
                    .adsr => |adsr| state.adsr.* = adsr,
                    .vol => |vol| state.volume.* = vol,
                    .slide => |freq| state.freq.* = freq,
                    .rest => |rest| {
                        // w4.trace("rest");
                        state.next.* = this.counter + rest.duration;
                    },
                    .note => |note| {
                        var freq = if (state.freq.*) |freq| (freq |
                            (@intCast(u32, note.freq) << 16)) else note.freq;
                        defer state.freq.* = null;
                        var flags = @intCast(u8, i) | state.param.*;

                        w4.tone(freq, state.adsr.*, state.volume.*, flags);

                        state.next.* = this.counter + note.duration;

                        // debug
                        util.trace("c {d:>2} f {d:>4} g {d:>4} l {d:>3} adsr {x:>8} vol {d:>3} flg {b:0>4}  p {b:0>4}", .{
                            i,
                            note.freq,
                            if (state.freq.*) |f| f else 0,
                            note.duration,
                            state.adsr.*,
                            state.volume.*,
                            flags,
                            state.param.*,
                        });
                    },
                }
                state.cursor.* = (state.cursor.* + 1);
                if (state.cursor.* >= song.events.len) break;
            }
        }
    }
};
