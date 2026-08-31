//! Since the only caller is the UI renderer;
//! which is already building;
//! one big output buffer through a writer;
//! these write directly into `anytype writer`;
//! instead of allocating their own little String;
//! same idea, more idiomatic for zig:
const std = @import("std");

const UNITS = [_][]const u8{ "B", "KB", "MB", "GB", "TB" };

pub fn writeBytes(writer: anytype, bytes: u64) !void {
    if (bytes == 0) {
        try writer.writeAll("0 B");
        return;
    }

    var val: f64 = @floatFromInt(bytes);
    var i: usize = 0;
    while (val >= 1024.0 and i < UNITS.len - 1) {
        val /= 1024.0;
        i += 1;
    }
    try writer.print("{d:.2} {s}", .{ val, UNITS[i] });
}

pub fn writePercent(writer: anytype, val: f32) !void {
    try writer.print("{d:.1}%", .{val});
}
