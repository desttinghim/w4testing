const w4 = @import("wasm4.zig");
const game = @import("game.zig");
const std = @import("std");

var errBuf: [100:0]u8 = undefined;
var errOpt: ?[]const u8 = null;

// Interface
export fn start() void {
    game.start() catch |e| err(e);
}

export fn update() void {
    if (errOpt) |errmsg| {
        w4.text(errmsg.ptr, 0, 0);
        w4.trace(errmsg.ptr);
    } else {
        game.update() catch |e| err(e);
    }
}

fn err(e: anyerror) void {
    const name = @errorName(e);
    std.mem.copy(u8, &errBuf, name);
    errBuf[name.len + 1] = 0;
    errOpt = errBuf[0..name.len];
    w4.trace(&errBuf);
}
