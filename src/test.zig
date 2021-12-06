const alda = @import("alda.zig");

comptime {
    _ = alda;
}

pub const song =
    \\ !tempo 112
    \\ !time 4/4
    \\ !instrument pulse50
    \\ o3
    \\ (mp) c4 c g g | a a g2 | f4 f e e | d d c2
    \\ g4 g f f | e e d2 | g4 g f f | e e d2
    \\ c4 c g g | a a g2 | f4 f e e | d d c2
;

test "parse twinkle twinkle little star" {
    _ = try alda.parseAlda(100, song);
}

test "parse sound effects" {
    _ = try alda.parseAlda(20, @embedFile("../assets/getFruit.txt"));
    _ = try alda.parseAlda(20, @embedFile("../assets/gameOver.txt"));
}
