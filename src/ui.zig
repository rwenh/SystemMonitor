//! In Zig, the frame is rendered upon one big string built in mem,
//! issuing a single write() of the whole thing per frame (avoids
//! the flicker a clear-then-redraw approach would cause).
//! `\x1b[K` (erase to end of line) after every line's content is what keeps stale
//! characters from a previous, longer frame from lingering - cheaper than tracking
//! exact visible-width padding around embedded color codes.
//!
//! Simpler layout without a full grid system / without pixel-perfect box alignment
//! around ANSI color codes.
const std = @import("std");
const models = @import("models.zig");
const Controller = @import("controller.zig").Controller;
const term = @import("term.zig");
const utils = @import("utils.zig");

const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const CYAN = "\x1b[36m";
const YELLOW = "\x1b[33m";
const BLUE = "\x1b[34m";
const GREEN = "\x1b[32m";
const REVERSE = "\x1b[7m";
const EOL = "\x1b[K\n";

pub const Ui = struct {
    buf: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) Ui {
        return .{ .buf = std.ArrayList(u8).init(allocator) };
    }

    pub fn deinit(self: *Ui) void {
        self.buf.deinit();
    }

    pub fn render(
        self: *Ui,
        terminal: *term.Term,
        metrics: *const models.SystemMetrics,
        controller: *const Controller,
        process_limit: usize,
    ) !void {
        // Silence unused parameter warnings for now
        _ = controller;
        _ = process_limit;

        self.buf.clearRetainingCapacity();
        const w = self.buf.writer();
        const size = terminal.size();

        // Move cursor home
        try w.writeAll("\x1b[H");

        // Header
        try w.writeAll(BOLD ++ CYAN ++ "System Monitor" ++ RESET ++
            "  |  " ++ YELLOW ++ "q" ++ RESET ++ " to quit  |  " ++
            YELLOW ++ "↑↓" ++ RESET ++ " navigate  |  " ++
            YELLOW ++ "PgUp/PgDn" ++ RESET ++ " page" ++ EOL);

        try writeRule(w, size.cols);

        // CPU line
        try w.writeAll("CPU     ");
        try writeBar(w, BLUE, metrics.cpu.usage_percent / 100.0, 30);

        // TODO: The rest of the UI (Memory, Disk, Network, Process list) is still missing.
        // You will need to continue implementing the rendering here.
    }
};

fn writeRule(w: anytype, cols: u16) !void {
    var i: u16 = 0;
    while (i < cols) : (i += 1) {
        try w.writeAll("─");
    }
    try w.writeAll(EOL);
}

fn writeBar(w: anytype, color: []const u8, fraction: f32, width: usize) !void {
    const filled = @min(width, @as(usize, @intFromFloat(fraction * @as(f32, @floatFromInt(width)))));
    try w.writeAll(color);
    var i: usize = 0;
    while (i < filled) : (i += 1) {
        try w.writeAll("█");
    }
    while (i < width) : (i += 1) {
        try w.writeAll("░");
    }
    try w.writeAll(RESET);
    try w.print(" {d:.1}%{s}", .{ fraction * 100.0, EOL });
}
