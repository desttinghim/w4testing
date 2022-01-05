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

const Vec = struct {
    x: i32,
    y: i32,

    pub fn eq(this: @This(), other: @This()) bool {
        return this.x == other.x and this.y == other.y;
    }

    pub fn init(x: i32, y: i32) @This() {
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

const Entity = struct {
    pos: ?Vec = null,
    vel: ?Vec = null,
    spr: ?Spr = null,
};

const World = struct {
    entities: EntityPool,

    const EntityPool = std.BoundedArray(Entity, 100);
    const EntityEnum = std.meta.FieldEnum(Entity);
    const EntitySet = std.EnumSet(EntityEnum);
    const EntityQuery = struct {
        required: std.EnumSet(EntityEnum),
    };

    const fields = std.meta.fields(Entity);

    pub fn init() @This() {
        return @This(){
            .entities = EntityPool.init(0) catch unreachable,
        };
    }

    pub fn create(this: *@This(), entity: Entity) u32 {
        this.entities.append(entity) catch unreachable;
        return this.entities.len;
    }

    // pub fn destroy(this: *@This(), entity: u32) void {
    //     // TODO
    // }

    pub fn query(require: []const EntityEnum) EntityQuery {
        var q = EntitySet.init(.{});
        for (require) |f| {
            q.insert(f);
        }
        return EntityQuery{ .required = q };
    }

    pub fn process(this: *@This(), q: *EntityQuery, func: fn (e: *Entity) void) void {
        for (this.entities.slice()) |*e| {
            var matches = true;
            inline for (fields) |f| {
                const fenum = std.meta.stringToEnum(EntityEnum, f.name) orelse unreachable;
                const required = q.required.contains(fenum);
                const has = @field(e, f.name) != null;
                if (required and !has) matches = false;
                break;
            }
            if (matches) func(e);
        }
    }
};

var world = World.init();

pub fn start() !void {
    _ = world.create(.{
        .pos = Vec.init(10, 10),
        .spr = .{ .id = 90, .col = .{ 0, 1, 4 } },
        .vel = Vec.init(1, 1),
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

    var physicsQuery = World.query(&.{ .pos, .vel });
    world.process(&physicsQuery, moveProcess);
    var drawQuery = World.query(&.{ .pos, .spr });
    world.process(&drawQuery, drawProcess);

    wae.update();
}

fn drawProcess(e: *Entity) void {
    const pos = e.pos orelse unreachable;
    const spr = e.spr orelse unreachable;

    const sx = (spr.id % 10) * 16;
    const sy = (spr.id / 10) * 16;

    w4.DRAW_COLORS.* = spr.toDrawColor();
    w4.blitSub(&assets.tileset, pos.x, pos.y, 16, 16, sx, sy, assets.tilesetWidth, assets.tilesetFlags);
}

fn moveProcess(e: *Entity) void {
    var pos = e.pos orelse unreachable;
    const vel = e.vel orelse unreachable;

    pos.x = @mod(pos.x + vel.x, 160);
    pos.y = @mod(pos.y + vel.y, 160);

    e.pos = pos;
}
