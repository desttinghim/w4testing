const w4 = @import("wasm4.zig");
const palettes = @import("palettes.zig");

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

const Snake = struct {
    body: [25]?Point,
    direction: Point,

    pub fn draw(this: @This()) void {
        for (this.body) |partopt, i| {
            if (partopt) |part| {
                w4.DRAW_COLORS.* = if (i == 0) 0x0034 else 0x0003;
                w4.rect(part.x * 8, part.y * 8, 8, 8);
            } else {
                break;
            }
        }
    }
};

var snake: Snake = .{
    .body = .{
        Point.new(2, 0),
        Point.new(1, 0),
        Point.new(0, 0),
    } ++ .{null} ** 22,
    .direction = Point.new(1, 0),
};

export fn start() void {
    w4.PALETTE.* = palettes.hallowpumpkin;
}

export fn update() void {
    snake.draw();
}
