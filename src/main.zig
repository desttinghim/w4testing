const w4 = @import("wasm4.zig");
const palettes = @import("palettes.zig");
const std = @import("std");
const Point = @import("point.zig").Point;
const Snake = @import("snake.zig").Snake;

var errOpt: ?[]const u8 = null;
var snake = Snake.new() catch @panic("");
var frameCount: u32 = 0;
var prevState: u8 = 0;

// Game Code
const game = struct {
    fn start() !void {
        frameCount = 0;
        w4.PALETTE.* = palettes.moonlightgb;
        try snake.body.append(Point.new(1, 0));
        try snake.body.append(Point.new(2, 0));
        try snake.body.append(Point.new(3, 0));
    }

    fn input() void {
        const gamepad = w4.GAMEPAD1.*;
        const justPressed = gamepad & (gamepad ^ prevState);

        if (justPressed & w4.BUTTON_LEFT != 0) {
            snake.left();
        }
        if (justPressed & w4.BUTTON_RIGHT != 0) {
            snake.right();
        }
        if (justPressed & w4.BUTTON_UP != 0) {
            snake.up();
        }
        if (justPressed & w4.BUTTON_DOWN != 0) {
            snake.down();
        }

        prevState = gamepad;
    }

    fn update() !void {
        frameCount += 1;

        input();

        if (frameCount % 15 == 0) {
            snake.update();
        }

        snake.draw();
    }
};

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
