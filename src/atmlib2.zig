const std = @import("std");

pub const CommandTag = enum {
    Literal,
    NoteOn,
    NoteOff,
    Delay,
    Command,
    SingleParam,
    MultiParam,
    Reserved,
};

pub const Immediate = enum(u4) {
    TranspositionOff = 0,
    PatternEnd = 1,
    GlissandoOff,
    ArpeggioOff,
    NotecutOff,
    NoiseRetrigOff,
};
pub const SingleParam = enum(u4) {
    SetTransposition = 0,
    AddTransposition,
    SetTempo,
    AddTempo,
    SetVolume,
    NoiseRetrigOn,
    SetMod,
};
pub const MultiParam = enum(u4) {
    SetLoopPattern = 0,
    Slide,
    Call,
    GlissandoOn,
    ArpeggioOn,
    LongDelay,
    LFO,
};

pub const Command = union(CommandTag) {
    Literal: u8,
    NoteOn: u6,
    NoteOff: void,
    Delay: u6,
    Command: Immediate,
    SingleParam: SingleParam,
    MultiParam: struct { count: u4, command: MultiParam },
    Reserved: void,

    pub fn fromByte(commandByte: u8) @This() {
        // var bitset = std.IntegerBitSet(8).initEmpty();
        // bitset.mask = commandByte;
        const firstBit = 0b1000_0000 & commandByte;
        if (firstBit != 0) {
            // If the high bit is set, it is either reserved or a
            // multi-parameter command
            const reserved = 0b1111_0000 & commandByte == 0b1111_0000;
            if (reserved) return .Reserved;
            const count = (0b0111_0000 & commandByte) >> 4;
            const command = (0b0000_1111 & commandByte);
            return .{ .MultiParam = .{
                .count = @truncate(u4, count + 1),
                .command = @intToEnum(MultiParam, @truncate(u4, command)),
            } };
        }

        const secondBit = 0b0100_0000 & commandByte;
        if (secondBit != 0) {
            // If the first bit was 0 and the second bit is 0, it is a note
            const note = 0b0011_1111 & commandByte;
            if (note == 0) return .NoteOff;
            return .{ .NoteOn = note };
        }

        const thirdBit = 0b0010_0000 & commandByte;
        if (thirdBit == 0) {
            const delay = 0b0001_1111 & commandByte;
            return .{ .Delay = @truncate(u6, delay + 1) };
        }

        const fourthBit = 0b0001_0000;
        const command = 0b0000_1111 & commandByte;
        if (fourthBit == 0) {
            return .{ .Command = @intToEnum(Immediate, @truncate(u4, command)) };
        }

        return .{ .SingleParam = @intToEnum(SingleParam, @truncate(u4, command)) };
    }

    pub fn toByte(this: @This()) u8 {
        return switch (this) {
            .Literal => |lit| lit,
            .NoteOn => |note| 0b0011_1111 & note,
            .NoteOff => 0b0000_0000,
            .Delay => |delay| 0b0100_0000 | @as(u8, (delay - 1)),
            .Command => |cmd| 0b0110_0000 | @as(u8, @enumToInt(cmd)),
            .SingleParam => |cmd| 0b0111_0000 | @as(u8, @enumToInt(cmd)),
            .MultiParam => |cmd| 0b1000_0000 | (@as(u8, cmd.count - 1) << 4) | @as(u8, @enumToInt(cmd.command)),
            .Reserved => 0b1111_0000,
        };
    }
};

pub const CommonHeader = struct {
    channelInfoPresent: bool,
    patternInfoPresent: bool,
    pub fn fromByte(byte: u8) @This() {
        return @This(){
            .channelInfoPresent = (0b0000_0001 & byte) != 0,
            .patternInfoPresent = (0b0000_0010 & byte) != 0,
        };
    }

    pub fn toByte(this: @This()) u8 {
        const channelFlag: u8 = if (this.channelInfoPresent) 0b0000_0001 else 0;
        const patternFlag: u8 = if (this.patternInfoPresent) 0b0000_0010 else 0;
        return channelFlag | patternFlag;
    }
};

pub const PatternHeader = struct {
    patternCount: u6,
    patternOffsets: []u16,

    pub fn fromBytes(bytes: []const u8) @This() {
        const patternCount = 0b0011_1111 & bytes[0];
        return @This(){
            .patternCount = patternCount,
            .patternOffsets = bytes[1 .. (2 * patternCount) + 1],
        };
    }

    pub fn toBytes(this: @This(), bytes: []u8) usize {
        bytes[0] = this.patternCount;
        std.mem.copy(u8, @ptrCast(*u8, this.patternOffsets), bytes[1..]);
        return (this.patternOffsets * 2) + 1;
    }
};

pub const ChannelHeader = struct {
    count: u2,
    entryPatterns: []u8,

    pub fn fromBytes(bytes: []const u8) @This() {
        const count = @truncate(u2, 0b0000_0011 & bytes[0]);
        return @This(){
            .count = count,
            .entryPatterns = bytes[1 .. count + 1],
        };
    }

    pub fn toBytes(this: @This(), bytes: []u8) usize {
        bytes[0] = this.count;
        std.mem.copy(u8, this.entryPatterns, bytes[1..]);
        return this.entryPatterns.len + 1;
    }
};

pub const Score = struct {
    common_header: CommonHeader,
    pattern_info: ?PatternHeader,
    channel_info: ?ChannelHeader,
    // extensions: void, // could be anything
    pattern_data: []const Command,

    pub fn toBytes(this: @This(), bytes: []u8) void {
        var n: usize = 0;
        bytes[n] = this.common_header.toByte();
        n += 1;

        // if (this.common_header.patternInfoPresent) n += this.pattern_info.?.toBytes(bytes[n..]);
        // if (this.common_header.channelInfoPresent) n += this.channel_info.?.toBytes(bytes[n..]);

        for (this.pattern_data) |cmd, i| {
            bytes[n + i] = cmd.toByte();
        }
    }
};

test "binary music test" {
    const score = [_]u8{
        0b0000_0000, // Common header, no pattern or channel info
        0b0111_0100, // Set volume to following byte
        0b0001_1111, // literal 31
        0b0001_1001, // Note C4
        0b0101_1000, // Delay 25 ticks
        0b0110_0001, // Stop
    };

    const zig_score = Score{
        .common_header = .{ .channelInfoPresent = false, .patternInfoPresent = false },
        .pattern_info = null,
        .channel_info = null,
        .pattern_data = &[_]Command{
            .{ .SingleParam = .SetVolume },
            .{ .Literal = 31 },
            .{ .NoteOn = 25 },
            .{ .Delay = 25 },
            .{ .Command = .PatternEnd },
        },
    };

    var zig_score_bytes: [6]u8 = undefined;
    zig_score.toBytes(&zig_score_bytes);
    try std.testing.expectEqualSlices(u8, &score, &zig_score_bytes);
}
