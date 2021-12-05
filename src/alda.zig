const std = @import("std");
const music = @import("music.zig");
const Event = music.Event;

pub const song =
    \\ o3
    \\ c4 c g g | a a g2 | f4 f e e | d d c2
    \\ g4 g f f | e e d2 | g4 g d d | e e d2
    \\ c4 c g g | a a g2 | f4 f e e | d d c2
;
pub const parsed = parseAlda(42, song) catch |e| @compileError(@errorName(e));

const AldaCmd = enum { o };

/// Supports the following:
/// duration = [1 to 64][.]
/// {a-g}[+ or -][duration]
/// r[duration]
/// o[0-9]
/// <
/// >
/// (note)~(note)
fn parseAlda(comptime size: comptime_int, buf: []const u8) ![]const Event {
    @setEvalBranchQuota(3000);
    var eventlist = try std.BoundedArray(Event, size).init(0);
    var currentOctave = 3;
    var currentDuration = 4;
    var currentBeat = 0;
    var barDivision = 64;
    var tokIter = std.mem.tokenize(u8, buf, " \n\t");
    while (tokIter.next()) |tok| {
        if (tok[0] == '|') {
            if (currentBeat % barDivision != 0) return error.BarCheckFailed else continue;
        }
        if (std.meta.stringToEnum(AldaCmd, tok[0..1])) |cmd| {
            var param = try std.fmt.parseInt(u8, tok[1..tok.len], 10);
            switch (cmd) {
                .o => currentOctave = param,
            }
        } else {
            var note = tok[0];
            if (tok.len > 1) currentDuration = try std.fmt.parseInt(u8, tok[1..tok.len], 10);
            currentBeat += barDivision / currentDuration;
            try eventlist.append(Event{ .note = cton(currentOctave, note), .duration = currentDuration });
        }
    }
    return eventlist.constSlice();
}

// fn parseNote(buf: []const u8) u8 {
//     // for (buf) |char| {
// }

// fn parseDuration(buf: []const u8) u8 {
//     for (buf) |char| {
//         switch (char) {
//             '0', '1', '2', '4', '8', '3', '5', '6', '7', '9' => {},
//             '.' => {},
//         }
//     }
// }

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
