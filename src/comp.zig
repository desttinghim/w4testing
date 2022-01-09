const std = @import("std");

pub const Vec = struct {
    x: i32,
    y: i32,

    pub fn eq(this: @This(), other: @This()) bool {
        return this.x == other.x and this.y == other.y;
    }

    pub fn init(x: i32, y: i32) @This() {
        return @This(){ .x = x, .y = y };
    }

    pub fn sub(this: @This(), other: @This()) @This() {
        return .{
            .x = this.x - other.x,
            .y = this.y - other.y,
        };
    }

    pub fn add(this: @This(), other: @This()) @This() {
        return .{
            .x = this.x + other.x,
            .y = this.y + other.y,
        };
    }

    pub fn div(this: @This(), scalar: i32) @This() {
        return .{
            .x = @divTrunc(this.x, scalar),
            .y = @divTrunc(this.y, scalar),
        };
    }
};

pub const AABB = struct {
    pos: Vec,
    size: Vec,

    pub fn init(x: i32, y: i32, w: i32, h: i32) @This() {
        return @This(){
            .pos = Vec.init(x, y),
            .size = Vec.init(w, h),
        };
    }

    pub fn addV(this: @This(), v: Vec) @This() {
        return .{
            .pos = this.pos.add(v),
            .size = this.size,
        };
    }

    pub fn subV(this: @This(), v: Vec) @This() {
        return .{
            .pos = this.pos.sub(v),
            .size = this.size,
        };
    }

    pub fn overlaps(this: @This(), other: @This()) bool {
        return this.x < other.x + other.w and
            this.x + this.w > other.x and
            this.y < other.y + other.h and
            this.y + this.h > other.y;
    }

    pub fn distance_to(this: @This(), other: @This()) Vec {
        var delta = Vec.init(0, 0);

        if (this.x < other.x) {
            delta.x = other.x - (this.x + this.w);
        } else if (this.x > other.x) {
            delta.x = this.x - (other.x + other.w);
        }

        if (this.y < other.y) {
            delta.y = other.y - (this.y + this.w);
        } else if (this.y > other.y) {
            delta.y = this.y - (other.y + other.w);
        }
        return delta;
    }
};

pub const Pos = struct {
    cur: Vec,
    old: Vec,

    pub fn init(x: i32, y: i32) @This() {
        return @This(){ .cur = Vec.init(x, y), .old = Vec.init(x, y) };
    }
};

pub const Gravity = Vec;

pub const Kinematic = struct {
    collider: AABB,
};

pub const Spr = struct {
    id: u8,
    col: [3]u3,
    pub inline fn toDrawColor(spr: @This()) u16 {
        return @as(u16, spr.col[0]) << 8 | @as(u16, spr.col[1]) << 4 | @as(u16, spr.col[2]);
    }
};
