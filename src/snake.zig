const w4 = @import("wasm4.zig");
const std = @import("std");
const Point = @import("point.zig").Point;

pub const Snake = struct {
    body: std.BoundedArray(Point, 4000),
    direction: Point,
    nextDirectionOpt: ?Point,

    pub fn new() !@This() {
        return @This(){
            .body = try std.BoundedArray(Point, 4000).init(0),
            .direction = Point.new(1, 0),
            .nextDirectionOpt = null,
        };
    }

    pub fn update(this: *@This()) void {
        var body = this.body.slice();

        var i = body.len - 1;
        while (i > 0) : (i -= 1) {
            body[i].x = body[i - 1].x;
            body[i].y = body[i - 1].y;
        }

        if (this.nextDirectionOpt) |nextDirection| {
            this.direction = nextDirection;
            this.nextDirectionOpt = null;
        }

        body[0].x = @mod(body[0].x + this.direction.x, 20);
        body[0].y = @mod(body[0].y + this.direction.y, 20);

        if (body[0].x < 0) body[0].x = 19;
        if (body[0].y < 0) body[0].y = 19;
    }

    pub fn draw(this: @This()) void {
        for (this.body.constSlice()) |part, i| {
            w4.DRAW_COLORS.* = if (i == 0) 0x0034 else 0x0003;
            w4.rect(part.x * 8, part.y * 8, 8, 8);
        }
    }

    pub fn left(this: *@This()) void {
        if (this.direction.x == 0) {
            this.nextDirectionOpt = Point.new(-1, 0);
        }
    }

    pub fn right(this: *@This()) void {
        if (this.direction.x == 0) {
            this.nextDirectionOpt = Point.new(1, 0);
        }
    }

    pub fn up(this: *@This()) void {
        if (this.direction.y == 0) {
            this.nextDirectionOpt = Point.new(0, -1);
        }
    }

    pub fn down(this: *@This()) void {
        if (this.direction.y == 0) {
            this.nextDirectionOpt = Point.new(0, 1);
        }
    }

    pub fn isDead(this: @This()) bool {
        const body = this.body.constSlice();
        const head = body[0];
        for (body) |part, i| {
            if (i == 0) continue;
            if (part.eq(head)) return true;
        }
        return false;
    }
};
