const std = @import("std");
const w4 = @import("wasm4.zig");

pub fn trace(comptime fmt: []const u8, args: anytype) void {
    var buf: [100]u8 = undefined;
    var print = std.fmt.bufPrintZ(
        &buf,
        fmt,
        args,
    ) catch return;
    w4.trace(print);
}
