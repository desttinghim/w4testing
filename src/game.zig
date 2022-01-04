const std = @import("std");
const assets = @import("assets");

const w4 = @import("wasm4.zig");
const util = @import("util.zig");
const palettes = @import("palettes.zig");
const music = @import("music.zig");
const WAE = music.WAE;
const wael = @import("wael.zig");

var musicContext: music.Context = undefined;
var wae: WAE = undefined;

var frameCount: u32 = 0;
var prng = std.rand.DefaultPrng.init(0);
var random: std.rand.Random = undefined;

const Point = struct {
    x: i32,
    y: i32,

    pub fn eq(this: @This(), other: @This()) bool {
        return this.x == other.x and this.y == other.y;
    }

    pub fn new(x: i32, y: i32) @This() {
        return @This(){ .x = x, .y = y };
    }
};

const Spr = struct {
    id: u8,
    col: [3]u3,
    pub inline fn toDrawColor(spr: @This()) u16 {
        return @as(u16, spr.col[0]) << 8 | @as(u16, spr.col[1]) << 4 | @as(u16, spr.col[2]);
    }
};

const CompTag = enum {
    Pos,
    Vel,
    Spr,
};

const Comp = union(CompTag) {
    Pos: Point,
    Vel: Point,
    Spr: Spr,
};

const Query = std.EnumSet(CompTag);

const World = struct {
    const max = 20;

    // Components
    pos: [max]?Point = undefined,
    vel: [max]?Point = undefined,
    spr: [max]?Spr = undefined,

    count: u32 = 0,

    pub fn init() @This() {
        return @This(){};
    }

    pub fn create(this: *@This()) u32 {
        var ret = this.count;
        this.count += 1;
        return ret;
    }

    pub fn set(this: *@This(), entity: u32, comp: Comp) void {
        switch (comp) {
            .Pos => |pos| this.pos[entity] = pos,
            .Vel => |vel| this.vel[entity] = vel,
            .Spr => |spr| this.spr[entity] = spr,
        }
    }

    pub fn get(this: *@This(), entity: u32, comp: CompTag) Comp {
        return switch (comp) {
            .Pos => Comp{ .Pos = this.pos[entity].? },
            .Vel => Comp{ .Vel = this.vel[entity].? },
            .Spr => Comp{ .Spr = this.spr[entity].? },
        };
    }

    fn query(_: *@This(), comps: []const CompTag) Query {
        var q = Query.init(.{});
        for (comps) |comp| {
            q.insert(comp);
        }
        return q;
    }

    pub fn process(this: *@This(), required: Query, func: fn (world: *@This(), entity: u32) void) void {
        var i: u32 = 0;
        while (i < this.count) : (i += 1) {
            const posCheck = !required.contains(.Pos) or (required.contains(.Pos) and this.pos[i] != null);
            const velCheck = !required.contains(.Vel) or (required.contains(.Vel) and this.vel[i] != null);
            const sprCheck = !required.contains(.Spr) or (required.contains(.Spr) and this.pos[i] != null);
            if (posCheck and velCheck and sprCheck) {
                func(this, i);
            }
        }
    }
};

var _world = World.init();

pub fn start() !void {
    var e = _world.create();
    var pos = Point.new(0, 0);
    _world.set(e, Comp{ .Pos = pos });
    var spr = Spr{ .id = 90, .col = .{ 0, 0, 4 } };
    _world.set(e, Comp{ .Spr = spr });
    var vel = Point.new(1, 1);
    _world.set(e, Comp{ .Vel = vel });

    util.trace("{} {x}", .{ spr.id, spr.toDrawColor() });

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

    _world.process(_world.query(&.{ .Pos, .Spr }), drawProcess);
    _world.process(_world.query(&.{ .Pos, .Vel }), moveProcess);

    wae.update();
}

fn drawProcess(world: *World, e: u32) void {
    const pos = world.get(e, .Pos).Pos;
    const spr = world.get(e, .Spr).Spr;

    const sx = (spr.id % 10) * 16;
    const sy = (spr.id / 10) * 16;

    w4.DRAW_COLORS.* = spr.toDrawColor();
    w4.blitSub(&assets.tileset, pos.x, pos.y, 16, 16, sx, sy, assets.tilesetWidth, assets.tilesetFlags);
}

fn moveProcess(world: *World, e: u32) void {
    var pos = world.get(e, .Pos).Pos;
    const vel = world.get(e, .Vel).Vel;

    pos.x = @mod(pos.x + vel.x, 160);
    pos.y = @mod(pos.y + vel.y, 160);

    world.set(e, .{ .Pos = pos });
}
