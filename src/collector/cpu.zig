//! Blocking the whole collection pass for 200ms every tick is wasteful;
//! keeping the previos /proc/stat sample in the collector and diffs it
//! against the current one each call -
//! The std technique tools like top/htop use - so collect() never
//! blocks. The only visible effect is that CPU% reads 0 for the very
//! first frame, then is accurate from the second frame on.

const std = @import("std");
const models = @import("../models.zig");

pub const CpuCollector = struct {
    prev_total: u64 = 0,
    prev_idle: u64 = 0,
    initialized: bool = false,

    pub fn init() CpuCollector {
        return .{};
    }

    pub fn collect(self: *CpuCollector, arena: std.mem.Allocator) !models.CpuMetrics {
        const core_count = std.Thread.getCpuCount() catch 1;

        var usage: f32 = 0.0;
        if (readProcStatCpu()) |sample| {
            if (self.initialized) {
                const total_delta = sample.total -| self.prev_total;
                const idle_delta = sample.idle -| self.prev_idle;
                if (total_delta > 0) {
                    const raw: f64 = (1.0 - @as(f64, @floatFromInt(idle_delta)) / @as(f64, @floatFromInt(total_delta))) * 100.0;
                    usage = @floatCast(@max(raw, 0.0));
                }
            }
            self.prev_total = sample.total;
            self.prev_idle = sample.idle;
            self.initialized = true;
        } else |_| {
            // /proc/stat unreadable; leave usage at 0 for this frame.
        }

        const brand = readBrand(arena) catch try arena.dupe(u8, "Unknown");

        return models.CpuMetrics{
            .brand = brand,
            .usage_percent = usage,
            .core_count = core_count,
        };
    }
};

const StatSample = struct { total: u64, idle: u64 };

fn readProcStatCpu() !StatSample {
    var buf: [512]u8 = undefined;
    const file = try std.fs.cwd().openFile("/proc/stat", .{});
    defer file.close();
    const n = try file.readAll(&buf);
    const content = buf[0..n];

    const nl = std.mem.indexOfScalar(u8, content, '\n') orelse content.len;
    const line = content[0..nl]; // "cpu  user nice system idle iowait irq softirq steal ..."

    var it = std.mem.tokenizeAny(u8, line, " \t");
    _ = it.next(); // "cpu"

    var values: [8]u64 = [_]u64{0} ** 8;
    var i: usize = 0;
    while (it.next()) |tok| : (i += 1) {
        if (i >= values.len) break;
        values[i] = std.fmt.parseInt(u64, tok, 10) catch 0;
    }

    // values: [user, nice, system, idle, iowait, irq, softirq, steal]
    const idle_all = values[3] + values[4];
    var total: u64 = 0;
    for (values) |v| total += v;

    return StatSample{ .total = total, .idle = idle_all };
}

fn readBrand(allocator: std.mem.Allocator) ![]const u8 {
    const content = try std.fs.cwd().readFileAlloc(allocator, "/proc/cpuinfo", 1 << 20);
    var lines = std.mem.tokenizeScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "model name")) {
            if (std.mem.indexOfScalar(u8, line, ':')) |idx| {
                const val = std.mem.trim(u8, line[idx + 1 ..], " \t");
                return allocator.dupe(u8, val);
            }
        }
    }

    return error.NotFound; // e.g. some ARM boards lack "model name"; caller falls back to "Unknown"
}
