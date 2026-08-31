//! package would be in the one piece of this whole port;
//! So instead this hand-rolls a tiny parser/writer for exactly the
//! two fields this project has.
const std = @import("std");

pub const Settings = struct {
    update_ms: u64 = 1000,
    process_limit: usize = 15,

    pub fn default() Settings {
        return .{};
    }

    pub fn load(allocator: std.mem.Allocator) !Settings {
        const path = try configPath(allocator);
        defer allocator.free(path);

        const file = std.fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                const s = Settings.default();
                try s.save(allocator);
                return s;
            },
            else => return err,
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1 << 16);
        defer allocator.free(content);

        return parse(content);
    }

    pub fn save(self: Settings, allocator: std.mem.Allocator) !void {
        const path = try configPath(allocator);
        defer allocator.free(path);

        if (std.fs.path.dirname(path)) |dir| {
            try std.fs.cwd().makePath(dir);
        }

        const file = try std.fs.createFileAbsolute(path, .{});
        defer file.close();

        var buf: [256]u8 = undefined;
        const text = try std.fmt.bufPrint(
            &buf,
            "update_ms = {d}\nprocess_limit = {d}\n",
            .{ self.update_ms, self.process_limit },
        );
        try file.writeAll(text);
    }
};

fn parse(content: []const u8) Settings {
    var s = Settings.default();
    var lines = std.mem.tokenizeAny(u8, content, "\n\r");

    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t");
        if (line.len == 0 or line[0] == '#') continue;

        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eq], " \t");
        const val = std.mem.trim(u8, line[eq + 1 ..], " \t");

        if (std.mem.eql(u8, key, "update_ms")) {
            s.update_ms = std.fmt.parseInt(u64, val, 10) catch s.update_ms;
        } else if (std.mem.eql(u8, key, "process_limit")) {
            s.process_limit = std.fmt.parseInt(usize, val, 10) catch s.process_limit;
        }
    }
    return s;
}

fn configPath(allocator: std.mem.Allocator) ![]u8 {
    if (std.posix.getenv("XDG_CONFIG_HOME")) |xdg| {
        if (xdg.len > 0) {
            return std.fs.path.join(allocator, &.{ xdg, "system-monitor", "config.toml" });
        }
    }
    const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
    return std.fs.path.join(allocator, &.{ home, ".config", "system-monitor", "config.toml" });
}
