pub const Point = struct {
    x: i32,
    y: i32,

    pub fn eq(this: @This(), other: @This()) bool {
        return this.x == other.x and this.y == other.y;
    }

    pub fn new(x: i32, y: i32) @This() {
        return @This(){ .x = x, .y = y };
    }
};
