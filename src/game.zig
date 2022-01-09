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
    physics: ?comp.Physics = null,
    spr: ?comp.Spr = null,
});
var world = World.init(fba.allocator());

pub fn start() !void {
    const pos = comp.Vec.init(10, 10);
    const phy = .{ .last_pos = comp.Vec.init(10, 9) };
    util.trace("{}, {}", .{ pos, phy });
    util.trace("{}", .{pos.sub(phy.last_pos)});
    _ = world.create(.{
        .pos = pos,
        .physics = phy,
        .spr = .{ .id = 90, .col = .{ 0, 1, 4 } },
    });

    random = prng.random();
    frameCount = 0;
    w4.PALETTE.* = palettes.en4;
    musicContext = comptime try wael.parse(@embedFile("../assets/music.txt"));
    wae = WAE.init(musicContext);
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

    world.process(&.{ .pos, .physics }, moveProcess);
    world.process(&.{ .pos, .spr }, drawProcess);

    wae.update();
}

fn drawProcess(posptr: *comp.Vec, sprptr: *comp.Spr) void {
    const pos = posptr.*;
    const spr = sprptr.*;

    const sx = (spr.id % 10) * 16;
    const sy = (spr.id / 10) * 16;

    w4.DRAW_COLORS.* = spr.toDrawColor();
    w4.blitSub(&assets.tileset, pos.x, pos.y, 16, 16, sx, sy, assets.tilesetWidth, assets.tilesetFlags);
}

fn abs(x: i32) i32 {
    return std.math.absInt(x) catch unreachable;
}

fn moveProcess(pos: *comp.Pos, physics: *comp.Physics) void {
    const last_pos = pos.*;
    const vel = pos.*.sub(physics.*.last_pos);
    var x = pos.*.x + vel.x;
    var y = pos.*.y + vel.y;
    if (x > 160) x = 160 - abs(vel.x);
    if (x < 0) x = abs(vel.x);
    if (y > 160) y = 160 - abs(vel.y);
    if (y < 0) y = abs(vel.y);
    pos.* = .{
        .x = x,
        .y = y,
    };
    physics.*.last_pos = last_pos;
}
