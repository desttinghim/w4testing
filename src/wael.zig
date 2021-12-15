const std = @import("std");
const music = @import("music.zig");
const BoundedArray = std.BoundedArray;
const Event = music.Event;
const Flag = music.Flag;
const Song = music.Song;
const CursorChannel = music.CursorChannel;

// utility functions
const isDigit = std.ascii.isDigit;
const toLower = std.ascii.toLower;

/// Read locations
const Dynamic = enum(u8) { pp = 1, p = 3, mp = 6, mf = 12, f = 25, ff = 50, fff = 100 };

/// Notes in music are based on fractions of a bar
const Duration = enum(u8) {
    whole = 1,
    half = 2,
    quarter = 4,
    quarter_triplet = 6,
    eighth = 8,
    sixteenth = 16,
    thirtysecond = 32,
    sixtyfourth = 64,
};
const Time = struct {
    /// Length of bar in ticks
    bar: u32 = 0,
    tempo: u32,
    /// Beats in a bar
    beats: u32,
    /// Value of a beat
    beatValue: u32,

    currentTick: u32 = 0,
    tripletTicks: [3]u32 = .{ 0, 0, 0 },

    /// Tempo
    pub fn init() @This() {
        var self = @This(){
            .tempo = 112,
            .beats = 4,
            .beatValue = 4,
        };
        self.updateBar();
        return self;
    }

    /// Appease the timing god by calling this with the proper duration
    pub fn tick(this: *@This(), duration: u32) u32 {
        var ret: u32 = 0;
        if (duration % 3 == 0) {
            // Triplet trouble
            if (this.tripletTicks[2] == 0) this.tripletTicks = this.triplets(duration);
            for (this.tripletTicks) |*tt| {
                if (tt.* == 0) continue;
                ret = tt.*;
                tt.* = 0;
                break;
            }
        } else {
            ret = this.getTicks(duration);
        }
        this.currentTick += ret;
        return ret;
    }

    pub fn barCheck(this: *@This()) bool {
        return this.currentTick % this.bar == 0;
    }

    pub fn setBar(this: *@This(), ticks: u32) void {
        this.bar = ticks;
    }

    pub fn setSpeed(this: *@This(), ticks: u32) void {
        this.setBar(ticks * this.beats);
    }

    fn updateBar(this: *@This()) void {
        this.bar = tempo2bar(this.tempo, this.beats);
    }

    pub fn setTempo(this: *@This(), tempo: u8) void {
        this.bar = (tempo * this.bar) / (this.beats * 60 * 60);
    }

    // TODO: Find out if this only makes sense when using tempo
    pub fn setSig(this: *@This(), beats: u8, beatValue: u8) void {
        const tempo = this.tempo;
        this.beats = beats;
        this.beatValue = beatValue;
        this.bar = @intCast(u8, tempo2bar(tempo, beats));
    }

    pub fn getTicks(this: @This(), duration: u32) u32 {
        return (this.bar * this.beatValue) / (this.beats * duration);
    }

    /// Triplets don't divide evenly, so everything sucks
    pub fn triplets(this: @This(), duration: u32) [3]u32 {
        // Rounds the number down
        const ticks = this.getTicks(duration);
        var ret = [_]u32{ ticks, ticks, ticks };
        // Get remainder
        const rem = ticks % duration;
        var correction = rem / (duration / 3);
        // Make a couple of the triplets longer to compensate for lack of
        // decimals
        var i: u8 = 0;
        while (correction > 0) : (i += 1) {
            ret[i] += 1;
            correction -= 1;
        }
        return ret;
    }
};

test "time keeping" {
    var time = Time.init();
    var tick: u32 = 0;

    // Testing triplets
    tick = time.tick(6);
    tick = time.tick(6);
    tick = time.tick(6);
    tick = time.tick(6);
    tick = time.tick(6);
    tick = time.tick(6);

    try std.testing.expectEqual(true, time.barCheck());

    time = Time.init();
    time.setTempo(112);
    try std.testing.expectEqual(@as(u32, 112), time.tempo);

    time = Time.init();
    time.setTempo(112);
    time.setSig(2, 4);
    try std.testing.expectEqual(@as(u32, 112), time.tempo);
}

const ReadTo = enum { a, d, r, adsr, spd, time, tempo, mode, goto };

const ReadMode = union(enum) { Define: u32, Set: struct { readTo: ReadTo, index: u32 }, Part: u32, Top };

const Instrument = struct { flags: u8, a: u8, d: u8, r: u8 };
const InstrumentList = BoundedArray(Instrument, 64);

const Part = struct { channel: CursorChannel, address: u16 };
const PartList = BoundedArray(Part, 64);

const SymbolType = enum { Instrument, Part, Song, Sfx };
const Symbol = struct { name: []const u8, sym: SymbolType, index: u32 };
const SymbolList = BoundedArray(Symbol, 64);

/// Parses a WAEL string into the song struct required by the WAE runner. Can be
/// run at comptime.
/// WAEL is specifically aimed at making music using the WAE runner working in a
/// WASM4 environment. No attempt has been made to generalize it, but feel free
/// to make variations that work in different environments.
/// TODO: Make it work at runtime
pub fn parse(buf: []const u8) !Song {
    @setEvalBranchQuota(20000);
    var song = try Song.init();

    var currentOctave: u8 = 3;
    var currentDuration: u8 = 4;
    var currentRows: u8 = 0;
    var currentDynamic: Dynamic = .mp;
    // var currentChannel: ?CursorChannel = null;
    var currentInstrument: ?Instrument = null;

    var parts = try PartList.init(0);
    var instruments = try InstrumentList.init(0);
    var symbols = try SymbolList.init(0);

    var readMode: ReadMode = .Top;

    var time = Time.init();

    var lineIter = std.mem.split(u8, buf, "\n");
    lineparse: while (lineIter.next()) |line| {
        var tokIter = std.mem.tokenize(u8, line, " \n\t");
        while (tokIter.next()) |tok| {
            if (tok[0] == '#') continue :lineparse;
            switch (readMode) {
                .Define => |defi| {
                    var symbol = symbols.get(defi);
                    if (tok[0] == ';') {
                        readMode = .Top;
                        if (symbol.sym == .Part) {
                            var position = @intCast(u16, song.events.len);
                            try song.events.append(Event{ .goto = position });
                        }
                        continue; // End definition
                    }
                    switch (symbol.sym) {
                        .Part => {
                            var part = parts.get(symbol.index);
                            switch (tok[0]) {
                                '@' => {
                                    part.channel = std.meta.stringToEnum(CursorChannel, tok[1..tok.len]) orelse return error.InvalidChannel;
                                    parts.set(symbol.index, part);
                                },
                                '[' => {
                                    // Place goto command in event list w/ temporary value
                                    var position = @intCast(u16, song.events.len);
                                    part.address = position;
                                    parts.set(symbol.index, part);
                                    readMode = .{ .Part = defi };
                                },
                                else => return error.InvalidToken,
                            }
                        },
                        .Instrument => {
                            switch (tok[0]) {
                                '!' => {
                                    readMode = .{ .Set = .{
                                        .readTo = std.meta.stringToEnum(ReadTo, tok[1..tok.len]) orelse return error.UnknownGlobal,
                                        .index = defi,
                                    } };
                                },
                                else => return error.InvalidToken,
                            }
                        },
                        else => return error.Unimplemented,
                    }
                    // readMode = .Top;
                },
                .Set => |s| {
                    switch (s.readTo) {
                        .a => {
                            var a = try std.fmt.parseInt(u8, tok, 16);
                            var i = instruments.get(symbols.get(s.index).index);
                            i.a = a;
                            instruments.set(s.index, i);
                            readMode = .{ .Define = s.index };
                            continue;
                        },
                        .d => {
                            var d = try std.fmt.parseInt(u8, tok, 16);
                            var i = instruments.get(symbols.get(s.index).index);
                            i.d = d;
                            instruments.set(s.index, i);
                            readMode = .{ .Define = s.index };
                            continue;
                        },
                        .r => {
                            var r = try std.fmt.parseInt(u8, tok, 16);
                            var i = instruments.get(symbols.get(s.index).index);
                            i.r = r;
                            instruments.set(s.index, i);
                            readMode = .{ .Define = s.index };
                            continue;
                        },
                        .spd => {
                            time.setSpeed(try std.fmt.parseInt(u8, tok, 10));
                        },
                        .time => {
                            time.setSig(tok[0] - '0', tok[2] - '0');
                        },
                        .tempo => {
                            time.setTempo(try std.fmt.parseInt(u8, tok, 10));
                        },
                        .mode => {
                            var flags = (try std.fmt.parseInt(u8, tok, 10)) << 2;
                            var i = instruments.get(symbols.get(s.index).index);
                            i.flags = flags;
                            instruments.set(s.index, i);
                            readMode = .{ .Define = s.index };
                            continue;
                        },
                        .adsr => try song.events.append(Event{ .adsr = try std.fmt.parseInt(u8, tok, 16) }),
                        .goto => {
                            var currentPart = parts.get(symbols.get(s.index).index);
                            for (symbols.constSlice()) |symbol| {
                                if (symbol.sym != .Part) continue;
                                var part = parts.get(symbol.index);
                                if (part.channel != currentPart.channel) continue;
                                if (std.mem.eql(u8, symbol.name, tok)) {
                                    try song.events.append(Event{ .goto = part.address });
                                    break;
                                }
                            } else {
                                std.log.warn("Unknown Label {s}", .{tok});
                                return error.UnknownLabel;
                            }
                        },
                    }
                    readMode = if (s.index == 255) .Top else .{ .Part = s.index };
                },
                .Part => |defi| {
                    switch (toLower(tok[0])) {
                        ']' => {
                            try song.events.append(Event.stop);
                            readMode = .{ .Define = defi };
                        },
                        '!' => {
                            readMode = .{ .Set = .{
                                .readTo = std.meta.stringToEnum(ReadTo, tok[1..tok.len]) orelse return error.UnknownGlobal,
                                .index = defi,
                            } };
                        },
                        '%' => {
                            // try song.events.append(Event{ .param = mode });
                            var instr: Instrument = undefined;
                            for (symbols.constSlice()) |symbol| {
                                if (symbol.sym != .Instrument) continue;
                                if (!std.mem.eql(u8, symbol.name, tok[1..tok.len])) continue;
                                instr = instruments.get(symbol.index);
                                break;
                            } else {
                                std.log.warn("{s}", .{tok});
                                return error.UnknownInstrument;
                            }
                            try song.events.append(Event{ .param = instr.flags });

                            currentInstrument = instr;
                        },
                        '|' => {
                            if (!time.barCheck()) return error.BarCheckFailed else continue;
                        },
                        // octave up
                        '>' => currentOctave = std.math.sub(u8, currentOctave, 1) catch return error.OctaveTooLow,
                        // octave down
                        '<' => currentOctave = std.math.add(u8, currentOctave, 1) catch return error.OctaveTooHigh,
                        '(' => {
                            currentDynamic = std.meta.stringToEnum(Dynamic, tok[1 .. tok.len - 1]) orelse return error.InvalidDynamic;
                            try song.events.append(Event{ .vol = @enumToInt(currentDynamic) });
                        },
                        'o' => if (tok.len > 1) {
                            currentOctave = (tok[1] - '0');
                        } else return error.MissingOctaveNumber,
                        else => {
                            // std.log.warn("{s}", .{tok});
                            var note_res = try parseNote(tok);
                            if (tok.len > 1 and note_res.end != tok.len) {
                                var duration_res = try parseDuration(tok[note_res.end + 1 .. tok.len]);
                                if (duration_res.duration != 0 and duration_res.end > 0) {
                                    currentDuration = duration_res.duration;
                                }
                                // TODO: implement ties (~)
                            }

                            // Update time keeping
                            var tick = time.tick(currentDuration);
                            if (currentRows != tick) {
                                if (currentInstrument) |instr| {
                                    const remainder = tick - (instr.a + instr.d + instr.r);
                                    try song.events.append(Event.init_adsr(instr.a, instr.d, remainder, instr.r));
                                    currentRows = @intCast(u8, tick);
                                }
                            }

                            if (note_res.note) |note| {
                                try song.events.append(Event.init_note(ntof(octave(currentOctave) + note), tick));
                            } else {
                                try song.events.append(Event.init_rest(tick));
                            }
                        },
                    }
                },
                .Top => {
                    switch (toLower(tok[0])) {
                        ':' => {
                            var t = std.meta.stringToEnum(SymbolType, tokIter.next() orelse return error.UnexpectedEOF) orelse return error.InvalidType;
                            var name = tokIter.next() orelse return error.UnexpectedEOF;
                            switch (t) {
                                .Instrument => {
                                    try instruments.append(Instrument{ .flags = 0, .a = 0, .d = 0, .r = 0 });
                                    try symbols.append(Symbol{ .name = name, .index = @intCast(u32, instruments.len - 1), .sym = .Instrument });
                                },
                                .Song => {
                                    return error.Unimplemented;
                                },
                                .Part => {
                                    var part: Part = .{ .channel = .none, .address = 255 };
                                    try parts.append(part);
                                    try symbols.append(Symbol{ .name = name, .index = @intCast(u32, parts.len - 1), .sym = .Part });
                                },
                                .Sfx => {
                                    return error.Unimplemented;
                                },
                            }
                            readMode = .{ .Define = @intCast(u32, symbols.len - 1) };
                        },
                        '!' => {
                            readMode = .{ .Set = .{
                                .readTo = std.meta.stringToEnum(ReadTo, tok[1..tok.len]) orelse return error.UnknownGlobal,
                                .index = 255,
                            } };
                        },
                        else => {
                            std.log.warn("Invalid Token: {s}", .{tok});
                            return error.InvalidToken;
                        },
                    }
                },
            }
        }
    }

    // for (parts.constSlice()) |sect, i| {
    //     const name = if (sect.name.len > 0) sect.name else "(unnamed)";
    //     std.log.warn("{} {s}: {}", .{ i, name, sect.address });
    // }

    // Find first part for each channel
    for (song.beginning) |begin, chani| {
        const channel = @intToEnum(CursorChannel, chani);
        if (begin >= song.events.len) {
            for (parts.constSlice()) |sect| {
                if (sect.channel != channel) continue;
                song.beginning[chani] = sect.address;
                break;
            }
        }
    }
    for (song.events.slice()) |event, i| {
        if (event == Event.goto and event.goto == i) {
            song.events.set(i, Event.stop);
        }
    }

    try song.events.append(Event.stop);

    return song;
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
        for (buf[1..buf.len]) |char, i| {
            switch (char) {
                '+' => note += 1,
                '-' => note -= 1,
                else => break i,
            }
        } else buf.len
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
        0 => 12,
        1 => 24,
        2 => 36,
        3 => 48,
        4 => 60,
        5 => 72,
        6 => 84,
        7 => 96,
        8 => 108,
        9 => 120,
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

fn tempo2beat(bpm: u32, beats: u32, beatValue: u32) u32 {
    return (beatValue * 60 * 60) / (bpm * beats);
}

fn tempo2bar(bpm: u32, beats: u32) u32 {
    // 60 * 60 == one minute in ticks
    return ((60 * 60) / bpm) * beats;
}

test "note2ticks" {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(tempo2bar(112, 4), 128);
    try expectEqual(tempo2bar(112, 2), 64);

    // 225bpm, 4/4 time
    try expectEqual(note2ticks(225, 4, 64), 1);
    try expectEqual(note2ticks(225, 4, 32), 2);
    try expectEqual(note2ticks(225, 4, 16), 4);
    try expectEqual(note2ticks(225, 4, 8), 8);
    try expectEqual(note2ticks(225, 4, 4), 16);
    try expectEqual(note2ticks(225, 4, 2), 32);
    try expectEqual(note2ticks(225, 4, 1), 64);

    // 112bpm, 4/4 time
    // Technically this is 112.5bpm, but
    // the 0.5 is lost in rounding
    try expectEqual(note2ticks(112, 4, 64), 2);
    try expectEqual(note2ticks(112, 4, 32), 4);
    try expectEqual(note2ticks(112, 4, 16), 8);
    try expectEqual(note2ticks(112, 4, 8), 16);
    try expectEqual(note2ticks(112, 4, 4), 32);
    try expectEqual(note2ticks(112, 4, 2), 64);
    try expectEqual(note2ticks(112, 4, 1), 128);

    // 75bpm, 4/4 time
    try expectEqual(note2ticks(75, 4, 64), 3);
    try expectEqual(note2ticks(75, 4, 32), 6);
    try expectEqual(note2ticks(75, 4, 16), 12);
    try expectEqual(note2ticks(75, 4, 8), 24);
    try expectEqual(note2ticks(75, 4, 4), 48);
    try expectEqual(note2ticks(75, 4, 2), 96);
    try expectEqual(note2ticks(75, 4, 1), 192);

    // 120bpm, 4/4 time
    try expectEqual(note2ticks(120, 4, 1), 120); // whole note = 120 frames
    try expectEqual(note2ticks(120, 4, 2), 60); // whole note = 60 frames
    try expectEqual(note2ticks(120, 4, 4), 30); // quarter note = 30 frames
    try expectEqual(note2ticks(120, 4, 8), 15); // eighth note = 15 frames
    // Any lower values are inexact. I'm going to not think about them for now...
    // TODO: figure out how faster notes will be handled
    // expectEqual(note2ticks(120, 4, 16) , 7.5);    // sixteenth note = 7 frames (inexact)
    // expectEqual(note2ticks(120, 4, 32) , 3.75);  // thirty-second note =  frames

    // 60bpm, 4/4 time
    try expectEqual(note2ticks(60, 4, 4), 60); // quarter note = 60 frames
}
