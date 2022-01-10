const std = @import("std");
const assets = @import("assets");

const w4 = @import("wasm4.zig");
const util = @import("util.zig");
const palettes = @import("palettes.zig");
const music = @import("music.zig");
const WAE = music.WAE;
const wael = @import("wael.zig");
const ecs = @import("ecs.zig");
const comp = @import("comp.zig");
const Vec = util.Vec;
const AABB = util.AABB;

var musicContext: music.Context = undefined;
var wae: WAE = undefined;

var frameCount: u32 = 0;
var prng = std.rand.DefaultPrng.init(0);
var random: std.rand.Random = undefined;

const KB = 1024;
var heap: [4 * KB]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&heap);

const World = ecs.World(struct {
    pos: ?comp.Pos = null,
    kinematic: ?comp.Kinematic = null,
    spr: ?comp.Spr = null,
    gravity: ?comp.Gravity = null,
    controller: ?comp.Controller = null,
});
var world = World.init(fba.allocator());

const level = [100]u8{
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  2,  2,  2,  2,
    2,  2,  2,  2,  2,  2,  2,  2,  8,  9,
    2,  1,  0,  1,  2,  2,  2,  2,  18, 19,
    0,  1,  0,  1,  0,  1,  0,  1,  0,  1,
    10, 11, 10, 11, 10, 11, 10, 11, 10, 11,
};

pub fn start() !void {
    const pos = comp.Pos.init(10, 10);
    const phy = .{ .collider = AABB.init(0, 0, 16, 16) };
    _ = world.create(.{
        .pos = pos,
        .kinematic = phy,
        .spr = .{ .id = 90, .col = .{ 0, 1, 4 } },
        .gravity = Vec.init(0, 1),
        .controller = comp.Controller.player(.GAMEPAD1),
    });

    random = prng.random();
    frameCount = 0;
    w4.PALETTE.* = palettes.en4;
    musicContext = comptime try wael.parse(@embedFile("../assets/music.txt"));
    wae = WAE.init(musicContext);
}

pub fn update() !void {
    frameCount += 1;

    // Process physics twice a frame
    var i: usize = 0;
    while (i < 2) : (i += 1) {
        world.process(&.{.pos}, velocityProcess);
        world.process(&.{ .pos, .gravity }, gravityProcess);
        world.process(&.{ .pos, .controller, .kinematic }, controllerProcess);
        world.process(&.{ .pos, .kinematic }, collisionProcess);
    }

    // Draw
    drawPreprocess();
    world.process(&.{ .pos, .spr }, drawProcess);
    drawPostprocess();

    wae.update();
}

inline fn draw_tile(x: i32, y: i32, w: i32, h: i32, tile: u8) void {
    const sw = assets.tilesetWidth / 16;
    var sx = (tile % sw) * 16;
    var sy = (tile / sw) * 16;
    w4.blitSub(&assets.tileset, x, y, w, h, sx, sy, assets.tilesetWidth, assets.tilesetFlags);
}

fn draw_map(tilemap: []const u8) void {
    w4.DRAW_COLORS.* = 0x0014;
    for (tilemap) |tile, index| {
        var i = @intCast(u8, index);
        var x = (i % 10) * 16;
        var y = (i / 10) * 16;
        draw_tile(x, y, 16, 16, tile);
    }
}

fn drawPreprocess() void {
    draw_map(&level);
}

fn drawProcess(posptr: *comp.Pos, sprptr: *comp.Spr) void {
    const pos = posptr.*.cur;
    const spr = sprptr.*;

    const sx = (spr.id % 10) * 16;
    const sy = (spr.id / 10) * 16;

    w4.DRAW_COLORS.* = spr.toDrawColor();
    w4.blitSub(&assets.tileset, @floatToInt(i32, pos.x), @floatToInt(i32, pos.y), 16, 16, sx, sy, assets.tilesetWidth, assets.tilesetFlags);
}

fn drawPostprocess() void {
    w4.DRAW_COLORS.* = 0x0014;
    // Draw these items over everything else
    draw_tile(144, 96, 16, 32, 9);
}

/// pos should be in tile coordinates, not world coordinates
fn get_tile(x: i32, y: i32) ?u8 {
    if (x < 0 or x > 9 or y < 0 or y > 9) return null;
    const i = x + y * 10;
    return level[@intCast(u32, i)];
}

/// rect should be absolutely positioned. Add pos to kinematic.collider
fn level_collide(rect: AABB) std.BoundedArray(AABB, 9) {
    const top_left = rect.pos.div(16);
    const bot_right = rect.pos.add(rect.size).div(16);
    var collisions = std.BoundedArray(AABB, 9).init(0) catch unreachable;

    var i: isize = @floatToInt(i32, top_left.x);
    while (i <= @floatToInt(i32, bot_right.x)) : (i += 1) {
        var a: isize = @floatToInt(i32, top_left.y);
        while (a <= @floatToInt(i32, bot_right.y)) : (a += 1) {
            var tile = get_tile(i, a);
            if (tile == null or tile.? != 2) collisions.append(AABB.init(@intToFloat(f32, i * 16), @intToFloat(f32, a * 16), 16, 16)) catch unreachable;
        }
    }

    return collisions;
}

const Pad = enum(u8) {
    LEFT = w4.BUTTON_LEFT,
    RIGHT = w4.BUTTON_RIGHT,
    UP = w4.BUTTON_UP,
    DOWN = w4.BUTTON_DOWN,
    ONE = w4.BUTTON_1,
    TWO = w4.BUTTON_2,
};

inline fn btn(input: u8, pad: Pad) bool {
    return (input & @enumToInt(pad) != 0);
}

inline fn btnp(input: u8, prev: u8, pad: Pad) bool {
    return (input & (input ^ prev) & @enumToInt(pad) != 0);
}

/// System for controlling entities with physics
fn controllerProcess(posptr: *comp.Pos, controllerptr: *comp.Controller, kinematicptr: *comp.Kinematic) void {
    const input = switch (controllerptr.control) {
        .player => |gamepad| switch (gamepad) {
            .GAMEPAD1 => w4.GAMEPAD1.*,
            .GAMEPAD2 => w4.GAMEPAD2.*,
            .GAMEPAD3 => w4.GAMEPAD3.*,
            .GAMEPAD4 => w4.GAMEPAD4.*,
        },
    };
    var pos = posptr.cur;
    var prev = controllerptr.prev;
    if (btn(input, .RIGHT)) pos.x += 1;
    if (btn(input, .LEFT)) pos.x -= 1;
    // Jump
    if (kinematicptr.onground and !btn(prev, .TWO)) controllerptr.*.aircontrol = controllerptr.AirControl;
    if (btnp(input, prev, .TWO) and kinematicptr.onground) {
        pos.y -= 8;
    }
    if (!kinematicptr.onground and controllerptr.aircontrol > 0 and btn(input, .TWO)) {
        pos.y -= 1;
        controllerptr.*.aircontrol -= 1;
    }
    if (btnp(input, prev, .ONE)) w4.tone(262, 0 | (10 << 8), 50, w4.TONE_PULSE1);
    posptr.*.cur = pos;
    controllerptr.prev = input;
}

fn velocityProcess(posptr: *comp.Pos) void {
    const cur = posptr.*.cur;
    const old = posptr.*.old;
    var vel = cur.sub(old);

    vel.x = @divTrunc(vel.x, 2);

    const next = cur.add(vel);

    posptr.*.cur = next;
    posptr.*.old = cur;
}

fn gravityProcess(posptr: *comp.Pos, gravityptr: *comp.Gravity) void {
    posptr.*.cur = posptr.*.cur.add(gravityptr.*);
}

fn collisionProcess(posptr: *comp.Pos, kinematicptr: *comp.Kinematic) void {
    const pos = posptr.*.cur;
    const old = posptr.*.old;
    const kinematic = kinematicptr.*;

    var next = Vec.init(pos.x, old.y);
    var collisions = level_collide(kinematic.collider.addV(next));
    if (collisions.len > 0) {
        next.x = old.x;
        kinematicptr.*.onwall = true;
    } else {
        kinematicptr.*.onwall = false;
    }

    next.y = pos.y;
    collisions = level_collide(kinematic.collider.addV(next));
    if (collisions.len > 0) {
        next.y = old.y;
        kinematicptr.*.onground = true;
    } else {
        kinematicptr.*.onground = false;
    }

    posptr.*.cur = next;
}
