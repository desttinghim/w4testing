const w4 = @import("wasm4.zig");
const std = @import("std");
const assets = @import("assets");
const palettes = @import("palettes.zig");
const Point = @import("point.zig").Point;
const Snake = @import("snake.zig").Snake;
const music = @import("music.zig");
const WAE = music.WAE;
const wael = @import("wael.zig");

var musicContext: music.Context = undefined;
var wae: WAE = undefined;

const songs = std.ComptimeStringMap(u16, .{
    .{ "gameOver", 0 },
    .{ "getFruit", 1 },
    .{ "getFruit2", 2 },
    .{ "spooky", 4 },
});
const getFruit = [_]u16{ 1, 2, 3 };
var getFruitNum: u16 = 0;

fn playSong(str: []const u8) void {
    if (songs.get(str)) |index| {
        if (index == 1) {
            wae.setNextSong(getFruit[getFruitNum]);
            getFruitNum = (getFruitNum + 1) % @intCast(u16, getFruit.len);
            return;
        }
        wae.playSong(index);
    }
}

var snake = Snake.new() catch @panic("");
var fruit: Point = undefined;
var prevState: u8 = 0;
var frameCount: u32 = 0;
var nextUpdate: u32 = 0;
var prng = std.rand.DefaultPrng.init(0);
var random: std.rand.Random = undefined;
var isDead: bool = false;

const fruitSprite = [16]u8{ 0x00, 0xa0, 0x02, 0x00, 0x0e, 0xf0, 0x36, 0x5c, 0xd6, 0x57, 0xd5, 0x57, 0x35, 0x5c, 0x0f, 0xf0 };

// Public functions

pub fn start() !void {
    isDead = false;
    random = prng.random();
    frameCount = 0;
    w4.PALETTE.* = palettes.en4;
    fruit = Point.new(rnd(20), rnd(20));
    try snake.body.resize(0);
    try snake.body.append(Point.new(3, 0));
    try snake.body.append(Point.new(2, 0));
    try snake.body.append(Point.new(1, 0));
    musicContext = comptime try wael.parse(@embedFile("../assets/music.txt"));
    wae = WAE.init(musicContext);
    playSong("spooky");
}

const tilemap = [100]u8{
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  2,  2,  8,  9,
    2,  2,  2,  2,  2,  2,  2,  2,  18, 19,
    0,  1,  0,  1,  0,  1,  0,  1,  0,  1,
    10, 11, 10, 11, 10, 11, 10, 11, 10, 11,
};

pub fn update() !void {
    frameCount += 1;

    w4.DRAW_COLORS.* = 0x0014;
    for (tilemap) |tile, index| {
        var i = @intCast(u8, index);
        var x = (i % 10) * 16;
        var y = (i / 10) * 16;
        var sx = (tile % 10) * 16;
        var sy = (tile / 10) * 16;
        w4.blitSub(&assets.tileset, x, y, 16, 16, sx, sy, assets.tilesetWidth, assets.tilesetFlags);
    }
    defer {
        w4.DRAW_COLORS.* = 0x0014;
        // Draw these items over everything else
        var tile: u8 = 9;
        var sx = (tile % 10) * 16;
        var sy = (tile / 10) * 16;
        w4.blitSub(&assets.tileset, 144, 96, 16, 16, sx, sy, assets.tilesetWidth, assets.tilesetFlags);
        w4.blitSub(&assets.tileset, 144, 112, 16, 16, sx, sy + 16, assets.tilesetWidth, assets.tilesetFlags);
    }

    wae.update();

    input();

    if (frameCount >= nextUpdate or snake.nextDirectionOpt != null) {
        nextUpdate = frameCount + 15;
        if (!snake.isDead()) {
            snake.update();
        }

        var checkDead = snake.isDead();
        if (checkDead and !isDead) playSong("gameOver");
        isDead = checkDead;

        const body = snake.body.constSlice();
        if (body[0].eq(fruit)) {
            var tail = body[body.len - 1];
            try snake.body.append(Point.new(tail.x, tail.y));
            fruit.x = rnd(20);
            fruit.y = rnd(20);
            playSong("getFruit");
            // w4.tone(0 | (1000 << 16), 0 | (15 << 8), 100, w4.TONE_TRIANGLE);
        }
    }

    snake.draw();

    w4.DRAW_COLORS.* = 0x4320;
    w4.blit(&fruitSprite, fruit.x * 8, fruit.y * 8, 8, 8, w4.BLIT_2BPP);

    if (isDead) {
        w4.DRAW_COLORS.* = 0x0034;
        w4.text("Snek ded", 40, 80);
    }
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
