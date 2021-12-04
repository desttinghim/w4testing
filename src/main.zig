const w4 = @import("wasm4.zig");
const game = @import("game.zig");

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
    errOpt = name;
    w4.trace(name.ptr);
}
