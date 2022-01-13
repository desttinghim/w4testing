const std = @import("std");
const wael = @import("wael.zig");
const atmlib2 = @import("atmlib2.zig");

comptime {
    _ = wael;
    _ = atmlib2;
}

pub const song =
    \\ # Tempo can be set by ticks
    \\ !spd 2
    \\ : Instrument basic !mode 2 ;
    \\ : Part a @p1 [ %basic
    \\ o3 (mp)
    \\ c4 c g g | a a g2 | f4 f e e | d d c2
    \\ g4 g f f | e e d2 | g4 g f f | e e d2
    \\ c4 c g g | a a g2 | f4 f e e | d d c2
    \\ ] ;
;

test "parse twinkle twinkle little star" {
    _ = try wael.parse(song);
}

test "parse getFruit" {
    const s1 = try wael.parse(@embedFile("../assets/getFruit.txt"));

    std.log.warn("{any}", .{s1.songs});
    for (s1.events.constSlice()) |e, i| {
        std.log.warn("{}: {}", .{ i, e });
    }
}

test "parse gameOver" {
    const s2 = try wael.parse(@embedFile("../assets/gameOver.txt"));

    std.log.warn("{any}", .{s2.songs});
    for (s2.events.constSlice()) |e, i| {
        std.log.warn("{}: {}", .{ i, e });
    }
}

test "parse music" {
    const c = try wael.parse(@embedFile("../assets/music.txt"));

    for (c.songs.constSlice()) |s, si| {
        for (s.constSlice()) |e, i| {
            std.log.warn("{}-{}: {}", .{ si, i, e });
        }
    }
    for (c.events.constSlice()) |e, i| {
        std.log.warn("{}: {}", .{ i, e });
    }
}
