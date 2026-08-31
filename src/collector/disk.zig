//! `sysinfo`'s disk list picks whatever the OS happens to enumerate first;
//! this targets "/" explicitly instead, which is more predictable and more
//! useful for a monitoring UI. Change `mount_point` below to watch a different
//! filesystem.
//! Implementation note: getting total/used space means either calling
//! statvfs(2)/statfs(2) or shelling out to `df`. The syscall route means
//! hand-declaring the kernel/libc struct layout over FFI with no way of
//! compile-check the field offsets in this sandbox - getting it wrong causes
//! buffer overrun, not just a compile error. Shelling out to the long-stable `df -P`
//! output is slightly less elegant but has no such failure mode.
const std = @import("std");
const models = @import("../models.zig");

pub const DiskCollector = struct {
    mount_point: []const u8 = "/",

    pub fn init() DiskCollector {
        return .{};
    }

    pub fn collect(self: *DiskCollector, arena: std.mem.Allocator) !models.DiskMetrics {
        var total_kb: u64 = 0;
        var used_kb: u64 = 0;

        if (runDf(self.mount_point, arena)) |output| {
            var lines = std.mem.tokenizeScalar(u8, output, '\n');
            _ = lines.next(); // header line

            if (lines.next()) |data_line| {
                var it = std.mem.tokenizeAny(u8, data_line, " \t");
                _ = it.next(); // filesystem name
                total_kb = std.fmt.parseInt(u64, it.next() orelse "0", 10) catch 0;
                used_kb = std.fmt.parseInt(u64, it.next() orelse "0", 10) catch 0;
            }
        } else |_| {
            // `df` missing or failed; fall through with zeroes rather than
            // taking down the whole collection pass.
        }

        const total = total_kb * 1024;
        const used = used_kb * 1024;

        return models.DiskMetrics{
            .total = total,
            .used = used,
            .percent = if (total > 0)
                @as(f32, @floatFromInt(used)) / @as(f32, @floatFromInt(total)) * 100.0
            else
                0.0,
            .mount_point = self.mount_point,
        };
    }
};

/// Runs `df -P -k <mount_point>` and returns its stdout.
/// -P: POSIX output format (stable column layout). -k: sizes in 1024-byte
/// blocks (more portable than GNU's `-B1`).
fn runDf(mount_point: []const u8, arena: std.mem.Allocator) ![]u8 {
    var child = std.process.Child.init(&.{ "df", "-P", "-k", mount_point }, arena);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;

    try child.spawn();

    const output = try child.stdout.?.reader().readAllAlloc(arena, 1 << 16);
    _ = child.wait() catch {};

    return output;
}
