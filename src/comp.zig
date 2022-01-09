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
};

pub const Pos = Vec;

pub const Physics = struct {
    last_pos: Vec,
};

pub const Spr = struct {
    id: u8,
    col: [3]u3,
    pub inline fn toDrawColor(spr: @This()) u16 {
        return @as(u16, spr.col[0]) << 8 | @as(u16, spr.col[1]) << 4 | @as(u16, spr.col[2]);
    }
};
