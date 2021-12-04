const w4 = @import("wasm4.zig");
const palettes = @import("palettes.zig");
const std = @import("std");
const Point = @import("point.zig").Point;
const Snake = @import("snake.zig").Snake;

var snake: Snake = undefined;
var errOpt: ?[]const u8 = null;

export fn start() void {
    box.start() catch |e| box.err(e);
}

export fn update() void {
    if (errOpt) |err| {
        w4.text(err.ptr, 0, 0);
        w4.trace(err.ptr);
        @panic("");
    } else {
        box.update() catch |e| box.err(e);
    }
}

const box = struct {
    fn err(e: anyerror) void {
        const name = @errorName(e);
        errOpt = name;
        w4.trace(name.ptr);
    }

    // So I can use stuff like try
    fn start() !void {
        w4.PALETTE.* = palettes.hallowpumpkin;
        snake = Snake.new();
        try snake.body.append(Point.new(1, 0));
        try snake.body.append(Point.new(2, 0));
        try snake.body.append(Point.new(3, 0));
    }

    fn update() !void {
        snake.update();
        snake.draw();
    }
};
