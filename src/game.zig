const w4 = @import("wasm4.zig");
const std = @import("std");
const palettes = @import("palettes.zig");
const Point = @import("point.zig").Point;
const Snake = @import("snake.zig").Snake;

var snake = Snake.new() catch @panic("");
var fruit: Point = undefined;
var prevState: u8 = 0;
var frameCount: u32 = 0;
var prng = std.rand.DefaultPrng.init(0);
var random: std.rand.Random = undefined;

const fruitSprite = [16]u8{ 0x00, 0xa0, 0x02, 0x00, 0x0e, 0xf0, 0x36, 0x5c, 0xd6, 0x57, 0xd5, 0x57, 0x35, 0x5c, 0x0f, 0xf0 };

// Public functions

pub fn start() !void {
    random = prng.random();
    frameCount = 0;
    w4.PALETTE.* = palettes.en4;
    fruit = Point.new(rnd(20), rnd(20));
    try snake.body.resize(0);
    try snake.body.append(Point.new(1, 0));
    try snake.body.append(Point.new(2, 0));
    try snake.body.append(Point.new(3, 0));
}

pub fn update() !void {
    frameCount += 1;

    input();

    if (frameCount % 15 == 0) {
        snake.update();
    }

    snake.draw();

    w4.DRAW_COLORS.* = 0x4320;
    w4.blit(&fruitSprite, fruit.x * 8, fruit.y * 8, 8, 8, w4.BLIT_2BPP);
}

// Private functions

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

fn rnd(n: i32) i32 {
    return random.intRangeLessThan(i32, 0, n);
}
