const w4 = @import("wasm4.zig");
const palettes = @import("palettes.zig");

const smiley = [8]u8{
    0b11000011,
    0b10000001,
    0b00100100,
    0b00100100,
    0b00000000,
    0b00100100,
    0b10011001,
    0b11000011,
};

const smiley2 = [8]u8{
    0b11000011,
    0b10000001,
    0b00100000,
    0b00100110,
    0b00000000,
    0b00100100,
    0b10011001,
    0b11000011,
};

export fn start() void {
    w4.PALETTE.* = palettes.fuzzyfour;
}

export fn update() void {
    w4.DRAW_COLORS.* = 2;
    w4.text("Hello from Zig!", 10, 10);

    w4.DRAW_COLORS.* = 1;
    w4.rect(0, 152, 8, 8);
    w4.DRAW_COLORS.* = 2;
    w4.rect(8, 152, 8, 8);
    w4.DRAW_COLORS.* = 3;
    w4.rect(16, 152, 8, 8);
    w4.DRAW_COLORS.* = 4;
    w4.rect(24, 152, 8, 8);

    const gamepad = w4.GAMEPAD1.*;
    if (gamepad & w4.BUTTON_1 != 0) {
        w4.DRAW_COLORS.* = 3;
        w4.blit(&smiley2, 76, 76, 8, 8, w4.BLIT_1BPP);
    } else {
        w4.blit(&smiley, 76, 76, 8, 8, w4.BLIT_1BPP);
    }

    w4.text("Press X to wink", 16, 90);
}
