//! Per-process CPU% needs two samples: this keeps the previous tick's
//! (utime+stime) per pid in a HashMap owned by the collector itself (NOT
//! the per-tick arena - it has to survive the arena reset every tick) and
//! diffs against it, same technique as cpu.zig and the same technique top/htop
//! use. CLK_TCK is hardcoded to 100, which is universal on Linux in practise
//! (querying sysconf(_SC_CLK_TCK) would be more "correct" also would have meant
//! pulling in libc for one constant that hasn't actually varied on any mainstream
//! Linux target in a very long time);
//!
//! Processes that exit mid-scan, or whose /proc files this user can't
//! read, are silently skipped - same effective behavior as sysinfo.
const std = @import("std");
const models = @import("../models.zig");

pub const ProcessCollector = struct {
    gpa: std.mem.Allocator,
    prev_times: std.AutoHashMap(u32, u64),
    prev_sample_ms: i64,

    const CLK_TCK: f64 = 100.0;

    pub fn init(gpa: std.mem.Allocator) ProcessCollector {
        return .{
            .gpa = gpa,
            .prev_times = std.AutoHashMap(u32, u64).init(gpa),
            .prev_sample_ms = 0,
        };
    }

    pub fn deinit(self: *ProcessCollector) void {
        self.prev_times.deinit();
    }

    pub fn collect(self: *ProcessCollector, arena: std.mem.Allocator) ![]models.ProcessInfo {
        const now_ms = std.time.milliTimestamp();
        const have_prev = self.prev_sample_ms != 0;
        const elapsed_ms = now_ms - self.prev_sample_ms;

        var list = std.ArrayList(models.ProcessInfo).init(arena);
        var new_times = std.AutoHashMap(u32, u64).init(self.gpa);
        errdefer new_times.deinit();

        var proc_dir = std.fs.cwd().openDir("/proc", .{ .iterate = true }) catch {
            return list.toOwnedSlice();
        };
        defer proc_dir.close();

        var it = proc_dir.iterate();
        while (it.next() catch null) |entry| {
            if (entry.kind != .directory) continue;

            const pid = std.fmt.parseInt(u32, entry.name, 10) catch continue;
            const total_ticks = readTotalTicks(arena, pid) catch continue;
            const name = readComm(arena, pid) catch continue;
            const mem_bytes = readRssBytes(arena, pid) catch 0;

            var cpu_pct: f32 = 0.0;
            if (have_prev and elapsed_ms > 0) {
                if (self.prev_times.get(pid)) |prev| {
                    const delta_ticks = total_ticks -| prev;
                    const elapsed_s = @as(f64, @floatFromInt(elapsed_ms)) / 1000.0;
                    const raw = (@as(f64, @floatFromInt(delta_ticks)) / CLK_TCK) / elapsed_s * 100.0;
                    cpu_pct = @floatCast(raw);
                }
            }

            new_times.put(pid, total_ticks) catch {};
            list.append(.{
                .pid = pid,
                .name = name,
                .cpu_usage = cpu_pct,
                .memory = mem_bytes,
            }) catch continue;
        }

        // Swap maps
        self.prev_times.deinit();
        self.prev_times = new_times;
        self.prev_sample_ms = now_ms;

        var slice = try list.toOwnedSlice();
        std.mem.sort(models.ProcessInfo, slice, {}, cpuDesc);
        if (slice.len > 50) slice = slice[0..50];
        return slice;
    }
};

fn cpuDesc(_: void, a: models.ProcessInfo, b: models.ProcessInfo) bool {
    return a.cpu_usage > b.cpu_usage;
}

fn readTotalTicks(arena: std.mem.Allocator, pid: u32) !u64 {
    // Note: the file is /proc/<pid>/stat  (not "state")
    const path = try std.fmt.allocPrint(arena, "/proc/{d}/stat", .{pid});
    const content = try std.fs.cwd().readFileAlloc(arena, path, 4096);

    // Skip the process name which is inside parentheses
    const close_paren = std.mem.lastIndexOfScalar(u8, content, ')') orelse return error.ParseFailed;
    var fields = std.mem.tokenizeAny(u8, content[close_paren + 1 ..], " \t\n");

    var idx: usize = 0;
    var utime: u64 = 0;
    var stime: u64 = 0;

    while (fields.next()) |tok| : (idx += 1) {
        if (idx == 11) { // utime is field 14 in /proc/pid/stat (0-based after the name → index 11)
            utime = std.fmt.parseInt(u64, tok, 10) catch 0;
        } else if (idx == 12) { // stime is the next field
            stime = std.fmt.parseInt(u64, tok, 10) catch 0;
            break;
        }
    }
    return utime + stime;
}

fn readComm(arena: std.mem.Allocator, pid: u32) ![]const u8 {
    const path = try std.fmt.allocPrint(arena, "/proc/{d}/comm", .{pid});
    const content = try std.fs.cwd().readFileAlloc(arena, path, 256);
    // Strip trailing newline
    return std.mem.trimRight(u8, content, "\n");
}

fn readRssBytes(arena: std.mem.Allocator, pid: u32) !u64 {
    const path = try std.fmt.allocPrint(arena, "/proc/{d}/status", .{pid});
    const content = try std.fs.cwd().readFileAlloc(arena, path, 1 << 16);

    var lines = std.mem.tokenizeScalar(u8, content, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "VmRSS:")) {
            var toks = std.mem.tokenizeAny(u8, line["VmRSS:".len..], " \t");
            const val = toks.next() orelse return 0;
            const kb = std.fmt.parseInt(u64, val, 10) catch 0;
            return kb * 1024;
        }
    }
    return 0;
}
