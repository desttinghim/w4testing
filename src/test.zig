const wael = @import("wael.zig");

comptime {
    _ = wael;
}

pub const song =
    \\ # Tempo can be set by ticks per bar...
    \\ !bar 128
    \\ # ...or in beats per minute. However, the BPM value is an approximation
    \\ # and the function is provided purely for the convenience of the author.
    \\ # Only certain values are supported.
    \\ #!tempo 112
    \\ #!time 4/4
    \\ !channel p1
    \\ !mode 2
    \\ o3
    \\ (mp) c4 c g g | a a g2 | f4 f e e | d d c2
    \\ g4 g f f | e e d2 | g4 g f f | e e d2
    \\ c4 c g g | a a g2 | f4 f e e | d d c2
;

test "parse twinkle twinkle little star" {
    _ = try wael.parse(song);
}

test "parse sound effects" {
    _ = try wael.parse(@embedFile("../assets/getFruit.txt"));
    _ = try wael.parse(@embedFile("../assets/gameOver.txt"));
}
