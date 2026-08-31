//! Uses MemAvailable (falling back to MemFree on ancient kernels that lacks)
//! rather than a naive MemTotal-MemFree, since MemAvailable accounts
//! for reclaimable cache/buffers - this is what modern `sysinfo`, `free`,
//! and `htop` all use for their "used" figure too.

const std = @import("std");
const models = @import("../models.zig");

pub const MemoryCollector = struct {
    pub fn init() MemoryCollector {
        return .{};
    }

    pub fn collect(self: *MemoryCollector, arena: std.mem.Allocator) !models.MemoryMetrics {
        _ = self;
        const content = try std.fs.cwd().readFileAlloc(arena, "/proc/meminfo", 1 << 16);

        var total_kb: u64 = 0;
        var avail_kb: u64 = 0;
        var free_kb: u64 = 0;
        var have_avail = false;

        var lines = std.mem.tokenizeScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "MemTotal:")) {
                total_kb = parseKb(line);
            } else if (std.mem.startsWith(u8, line, "MemAvailable:")) {
                avail_kb = parseKb(line);
                have_avail = true;
            } else if (std.mem.startsWith(u8, line, "MemFree:")) {
                free_kb = parseKb(line);
            }
        }

        const avail = if (have_avail) avail_kb else free_kb;
        const used_kb = if (total_kb > avail) total_kb - avail else 0;

        const total_bytes = total_kb * 1024;
        const used_bytes = used_kb * 1024;

        return models.MemoryMetrics{
            .total = total_bytes,
            .used = used_bytes,
            .percent = if (total_bytes > 0)
                @as(f32, @floatFromInt(used_bytes)) / @as(f32, @floatFromInt(total_bytes)) * 100.0
            else
                0.0,
        };
    }
};

/// Parses a "Label: 12345 kB" line and returns the numeric field.
fn parseKb(line: []const u8) u64 {
    var it = std.mem.tokenizeAny(u8, line, " \t");
    _ = it.next(); // the "Label:" token
    const val = it.next() orelse return 0;
    return std.fmt.parseInt(u64, val, 10) catch 0;
}
