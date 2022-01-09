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
    2,  2,  2,  2,  2,  2,  2,  2,  18, 19,
    0,  1,  0,  1,  0,  1,  0,  1,  0,  1,
    10, 11, 10, 11, 10, 11, 10, 11, 10, 11,
};

pub fn start() !void {
    const pos = comp.Vec.init(10, 10);
    const phy = .{ .last_pos = pos, .collider = comp.AABB.init(0, 0, 16, 16) };
    util.trace("{}, {}", .{ pos, phy });
    util.trace("{}", .{pos.sub(phy.last_pos)});
    _ = world.create(.{
        .pos = pos,
        .kinematic = phy,
        .spr = .{ .id = 90, .col = .{ 0, 1, 4 } },
    });

    random = prng.random();
    frameCount = 0;
    w4.PALETTE.* = palettes.en4;
    musicContext = comptime try wael.parse(@embedFile("../assets/music.txt"));
    wae = WAE.init(musicContext);
}

pub fn update() !void {
    frameCount += 1;

    world.process(&.{ .pos, .kinematic }, physicsProcess);

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

fn drawProcess(posptr: *comp.Vec, sprptr: *comp.Spr) void {
    const pos = posptr.*;
    const spr = sprptr.*;

    const sx = (spr.id % 10) * 16;
    const sy = (spr.id / 10) * 16;

    w4.DRAW_COLORS.* = spr.toDrawColor();
    w4.blitSub(&assets.tileset, pos.x, pos.y, 16, 16, sx, sy, assets.tilesetWidth, assets.tilesetFlags);
}

fn drawPostprocess() void {
    w4.DRAW_COLORS.* = 0x0014;
    // Draw these items over everything else
    draw_tile(144, 96, 16, 32, 9);
}

/// pos should be in tile coordinates, not world coordinates
fn get_tile(x: i32, y: i32) u8 {
    const i = x + y * 10;
    return level[@intCast(u32, i)];
}

/// rect should be absolutely positioned. Add pos to kinematic.collider
fn level_collide(rect: comp.AABB) std.BoundedArray(comp.AABB, 9) {
    const top_left = rect.pos.div(16);
    const bot_right = rect.pos.add(rect.size).div(16);
    var collisions = std.BoundedArray(comp.AABB, 9).init(0) catch unreachable;

    var i: isize = top_left.x;
    while (i <= bot_right.x) : (i += 1) {
        var a: isize = top_left.y;
        while (a <= bot_right.y) : (a += 1) {
            if (get_tile(i, a) != 2) collisions.append(comp.AABB.init(i * 16, a * 16, 16, 16)) catch unreachable;
        }
    }

    return collisions;
}

const GRAVITY = 1;

fn physicsProcess(posptr: *comp.Pos, kinematicptr: *comp.Kinematic) void {
    const current = posptr.*;
    const kinematic = kinematicptr.*;
    var vel = current.sub(kinematic.last_pos);
    vel.y += GRAVITY;
    var next = current;

    next.x += vel.x;
    var collisions = level_collide(kinematic.collider.addV(next));
    if (collisions.len > 0) {
        next.x = current.x;
    }

    next.y += vel.y;
    collisions = level_collide(kinematic.collider.addV(next));
    if (collisions.len > 0) {
        next.y = current.y;
    }

    posptr.* = next;
    kinematicptr.*.last_pos = current;
}
