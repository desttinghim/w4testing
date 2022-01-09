const std = @import("std");
const util = @import("util.zig");
const Vec = util.Vec;
const AABB = util.AABB;

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
    onground: bool = false,
    onwall: bool = false,
};

pub const Spr = struct {
    id: u8,
    col: [3]u3,
    pub inline fn toDrawColor(spr: @This()) u16 {
        return @as(u16, spr.col[0]) << 8 | @as(u16, spr.col[1]) << 4 | @as(u16, spr.col[2]);
    }
};

const Player = enum { GAMEPAD1, GAMEPAD2, GAMEPAD3, GAMEPAD4 };
pub const Controller = struct {
    prev: u8 = 0,
    AirControl: u8 = 4,
    aircontrol: u8 = 0,
    control: union(enum) { player: Player },

    pub fn player(p: Player) @This() {
        return @This(){
            .control = .{ .player = p },
        };
    }
};
