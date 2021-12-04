const w4 = @import("wasm4.zig");
const palettes = @import("palettes.zig");
const std = @import("std");
const Point = @import("point.zig").Point;
const Snake = @import("snake.zig").Snake;

var snake: Snake = undefined;
var errOpt: ?[*]const u8 = null;

export fn start() void {
    w4.PALETTE.* = palettes.hallowpumpkin;
    box.start() catch |e| {
        errOpt = @errorName(e).ptr;
    };
}

export fn update() void {
    if (errOpt) |err| {
        w4.text(err, 0, 0);
    } else {
        box.update() catch |e| {
            errOpt = @errorName(e).ptr;
        };
    }
}

const box = struct {
    // So I can use stuff like try
    fn start() !void {
        snake = Snake.new();
        try snake.body.append(Point.new(1, 0));
        try snake.body.append(Point.new(2, 0));
        try snake.body.append(Point.new(3, 0));
    }

    fn update() !void {
        snake.draw();
    }
};
