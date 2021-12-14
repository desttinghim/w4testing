const std = @import("std");
const wael = @import("wael.zig");

comptime {
    _ = wael;
}

pub const song =
    \\ # Tempo can be set by ticks
    \\ !spd 2
    \\ :@a p1 !mode 2
    \\ o3 (mp)
    \\ c4 c g g | a a g2 | f4 f e e | d d c2
    \\ g4 g f f | e e d2 | g4 g f f | e e d2
    \\ c4 c g g | a a g2 | f4 f e e | d d c2
;

test "parse twinkle twinkle little star" {
    _ = try wael.parse(song);
}

test "parse sound effects" {
    const s1 = try wael.parse(@embedFile("../assets/getFruit.txt"));
    const s2 = try wael.parse(@embedFile("../assets/gameOver.txt"));

    std.log.warn("{any}", .{s1.beginning});
    for (s1.events.constSlice()) |e, i| {
        std.log.warn("{}: {}", .{ i, e });
    }

    std.log.warn("{any}", .{s2.beginning});
    for (s2.events.constSlice()) |e, i| {
        std.log.warn("{}: {}", .{ i, e });
    }
}
