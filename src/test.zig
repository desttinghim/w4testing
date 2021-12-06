const alda = @import("alda.zig");

comptime {
    alda.parseTheSong() catch @compileError("thing");
}
