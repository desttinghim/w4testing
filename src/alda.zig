const std = @import("std");
const music = @import("music.zig");
const Event = music.Event;

pub const song =
    \\ o3
    \\ c4 c g g | a a g2 | f4 f e e | d d c2
    \\ g4 g f f | e e d2 | g4 g d d | e e d2
    \\ c4 c g g | a a g2 | f4 f e e | d d c2
;
pub const parsed = parseAlda(100, song) catch |e| @compileError(@errorName(e));

pub fn parseTheSong() !void {
    _ = try parseAlda(100, song);
}

// utility functions
const isDigit = std.ascii.isDigit;
const toLower = std.ascii.toLower;

/// Read locations
const ReadTo = enum { time, tempo };

const TimeSignature = struct {
    tempo: u8,
    upper: u8,
    lower: u8,

    /// Returns the length of a bar in ticks
    pub fn bar(this: @This()) u32 {
        return note2ticks(this.tempo, this.lower, 1);
    }

    pub fn ticks(this: @This(), duration: u32) u8 {
        return @intCast(u8, note2ticks(this.tempo, this.lower, duration));
    }
};

// TODO: make different instruments
// const Instrument = enum {pulse12, pulse25, pulse50, pulse75, triangle, noise};

/// Supports the following:
/// duration = [1 to 64][.]
/// {a-g}[+ or -][duration]
/// r[duration]
/// o[0-9]
/// <
/// >
/// (note)~(note)
/// ![keyword] value
/// :[instrument]
fn parseAlda(comptime size: comptime_int, buf: []const u8) ![]const Event {
    @setEvalBranchQuota(3000);
    var eventlist = try std.BoundedArray(Event, size).init(0);
    // registers
    var currentOctave: u8 = 3;
    var currentDuration: u8 = 4;
    var readToOpt: ?ReadTo = null;

    // timing
    var currentTick: u32 = 0;
    var time: TimeSignature = .{ .tempo = 112, .upper = 4, .lower = 4 };

    var tokIter = std.mem.tokenize(u8, buf, " \n\t");
    while (tokIter.next()) |tok| {
        if (readToOpt) |_| {
            // TODO: Implement setting variables
        }
        switch (toLower(tok[0])) {
            '!' => readToOpt = std.meta.stringToEnum(ReadTo, tok[1..tok.len]),
            '|' => if (currentTick % time.bar() != 0) return error.BarCheckFailed else continue,
            '<' => _ = std.math.sub(u8, currentOctave, 1) catch return error.OctaveTooLow,
            '>' => _ = std.math.add(u8, currentOctave, 1) catch return error.OctaveTooHigh,
            'o' => if (tok.len > 1) {
                currentOctave = (tok[1] - '0');
            } else return error.MissingOctaveNumber,
            else => {
                var note_res = try parseNote(tok);
                if (tok.len > 1 and note_res.end != tok.len) {
                    var duration_res = try parseDuration(tok[note_res.end + 1 .. tok.len]);
                    if (duration_res.duration != 0 and duration_res.end > 0) {
                        currentDuration = duration_res.duration;
                        var ticks = time.ticks(currentDuration);
                        // TODO: change adsr based on instrument
                        try eventlist.append(Event{ .sr = .{ .sustain = ticks, .release = 0 } });
                    }
                    // TODO: implement ties (~)
                }
                currentTick += time.ticks(currentDuration);
                if (note_res.note) |note| {
                    try eventlist.append(Event{ .note = ntof(currentOctave + note) });
                } else {
                    try eventlist.append(Event.rest);
                }
            },
        }
    }
    return eventlist.constSlice();
}

const NoteRes = struct { note: ?u8, end: usize };
fn parseNote(buf: []const u8) !NoteRes {
    var note: u8 = switch (buf[0]) {
        'c' => 0,
        'd' => 2,
        'e' => 4,
        'f' => 5,
        'g' => 7,
        'a' => 9,
        'b' => 11,
        'r' => return NoteRes{ .note = null, .end = 1 },
        else => return error.InvalidNote,
    };

    var end = if (buf.len > 1)
        for (buf) |char, i|
            switch (char) {
                '+' => note += 1,
                '-' => note -= 1,
                else => break i,
            }
        else
            buf.len
    else
        buf.len;
    return NoteRes{ .note = note, .end = end };
}

const DurationRes = struct { duration: u8, end: usize };
fn parseDuration(buf: []const u8) !DurationRes {
    var val: u8 = 0;
    var end: usize = for (buf) |char, i| {
        switch (char) {
            '0', '1', '2', '4', '8', '3', '5', '6', '7', '9' => {
                val = std.math.mul(u8, val, 10) catch return error.DurationMultiply;
                val = std.math.add(u8, val, (char - '0')) catch return error.DurationAdd;
            },
            else => break i,
        }
    } else buf.len;
    return DurationRes{ .duration = val, .end = end };
}

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

// note to frequency
fn ntof(note: u8) u16 {
    const a = 440.0;
    const n = @intToFloat(f32, note);
    return @floatToInt(u16, (a / 32.0) * std.math.pow(f32, 2.0, ((n - 9) / 12.0)));
}

/// Takes a note duration and returns the it as a frame duration (assumes 60 fps)
/// bpm = beats per minute
/// beatValue = lower part of time signature, indicates the value that is equivalent to a beat
/// duration = length of the note
fn note2ticks(bpm: u32, beatValue: u32, duration: u32) u32 {
    // whole = 240, half = 120, quarter = 60, etc.
    const one = (beatValue * 60 * 60);
    const two = bpm * duration;
    const ticks = one / two;
    return ticks;
}

test "note2ticks" {
    const assert = std.debug.assert;
    // 225bpm, 4/4 time
    assert(note2ticks(225, 4, 64) == 1);
    assert(note2ticks(225, 4, 32) == 2);
    assert(note2ticks(225, 4, 16) == 4);
    assert(note2ticks(225, 4, 8) == 8);
    assert(note2ticks(225, 4, 4) == 16);
    assert(note2ticks(225, 4, 2) == 32);
    assert(note2ticks(225, 4, 1) == 64);

    // 112bpm, 4/4 time
    // Technically this is 112.5bpm, but
    // the 0.5 is lost in rounding
    assert(note2ticks(112, 4, 64) == 2);
    assert(note2ticks(112, 4, 32) == 4);
    assert(note2ticks(112, 4, 16) == 8);
    assert(note2ticks(112, 4, 8) == 16);
    assert(note2ticks(112, 4, 4) == 32);
    assert(note2ticks(112, 4, 2) == 64);
    assert(note2ticks(112, 4, 1) == 128);

    // 75bpm, 4/4 time
    assert(note2ticks(75, 4, 64) == 3);
    assert(note2ticks(75, 4, 32) == 6);
    assert(note2ticks(75, 4, 16) == 12);
    assert(note2ticks(75, 4, 8) == 24);
    assert(note2ticks(75, 4, 4) == 48);
    assert(note2ticks(75, 4, 2) == 96);
    assert(note2ticks(75, 4, 1) == 192);

    // 120bpm, 4/4 time
    assert(note2ticks(120, 4, 1) == 120); // whole note = 120 frames
    assert(note2ticks(120, 4, 2) == 60); // whole note = 60 frames
    assert(note2ticks(120, 4, 4) == 30); // quarter note = 30 frames
    assert(note2ticks(120, 4, 8) == 15); // eighth note = 15 frames
    // Any lower values are inexact. I'm going to not think about them for now...
    // TODO: figure out how faster notes will be handled
    // assert(note2ticks(120, 4, 16) == 7.5);    // sixteenth note = 7 frames (inexact)
    // assert(note2ticks(120, 4, 32) == 3.75);  // thirty-second note =  frames

    // 60bpm, 4/4 time
    assert(note2ticks(60, 4, 4) == 60); // quarter note = 60 frames
}
