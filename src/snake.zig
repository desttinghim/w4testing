const w4 = @import("wasm4.zig");
const std = @import("std");
const Point = @import("point.zig").Point;

pub const Snake = struct {
    body: std.BoundedArray(Point, 4000),
    direction: Point,

    pub fn new() @This() {
        return @This(){
            .body = std.BoundedArray(Point, 4000).init(0) catch @panic("No snek"),
            .direction = Point.new(1, 0),
        };
    }

    pub fn update(this: *@This()) void {
        var body = this.body.slice();

        var i = body.len - 1;
        while (i > 0) : (i -= 1) {
            body[i].x = body[i - 1].x;
            body[i].y = body[i - 1].y;
        }
    }

    pub fn draw(this: @This()) void {
        for (this.body.constSlice()) |part, i| {
            w4.DRAW_COLORS.* = if (i == 0) 0x0034 else 0x0003;
            w4.rect(part.x * 8, part.y * 8, 8, 8);
        }
    }
};
