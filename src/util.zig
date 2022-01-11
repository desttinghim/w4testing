const std = @import("std");
const w4 = @import("wasm4.zig");

pub fn trace(comptime fmt: []const u8, args: anytype) void {
    var buf: [100]u8 = undefined;
    var print = std.fmt.bufPrintZ(
        &buf,
        fmt,
        args,
    ) catch return;
    w4.trace(print);
}

const T = f32;
pub const Vec = struct {
    x: T,
    y: T,

    pub fn eq(this: @This(), other: @This()) bool {
        return this.x == other.x and this.y == other.y;
    }

    pub fn init(x: T, y: T) @This() {
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

    pub fn div(this: @This(), scalar: T) @This() {
        return .{
            .x = @divTrunc(this.x, scalar),
            .y = @divTrunc(this.y, scalar),
        };
    }

    pub fn mul(this: @This(), scalar: T) @This() {
        return .{
            .x = this.x * scalar,
            .y = this.y * scalar,
        };
    }
};

pub const AABB = struct {
    pos: Vec,
    size: Vec,

    pub fn init(x: T, y: T, w: T, h: T) @This() {
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
