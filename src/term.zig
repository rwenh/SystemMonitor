//! `zig build` if exact compiler version's `std.posix` surface differs
//! even slightly - it's isolated on purpose
//! so any such fix stays contained to this file:
//! Handles: raw mode, the alternate screen, cursor visibility,
//! terminal size, and non-blocking key reads.
const std = @import("std");
const posix = std.posix;

pub const Key = enum {
    quit,
    up,
    down,
    page_up,
    page_down,
    none,
};

pub const Size = struct {
    rows: u16,
    cols: u16,
};

// struct winsize from <sys/ioctl.h>
const winsize = extern struct {
    row: u16,
    col: u16,
    xpixel: u16,
    ypixel: u16,
};

// TIOCGWINSZ on Linux
const TIOCGWINSZ: u32 = 0x5413;

// POLLIN
const POLLIN: i16 = 0x0001;

pub const Term = struct {
    orig_termios: posix.termios,
    stdout: std.fs.File,

    pub fn init() !Term {
        const stdin_fd = posix.STDIN_FILENO;
        const orig = try posix.tcgetattr(stdin_fd);

        var raw = orig;
        raw.iflag.BRKINT = false;
        raw.iflag.ICRNL = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;
        raw.iflag.IXON = false;
        raw.oflag.OPOST = false;
        raw.cflag.CSIZE = .CS8;
        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.IEXTEN = false;
        raw.lflag.ISIG = false;
        raw.cc[@intFromEnum(posix.V.MIN)] = 0;
        raw.cc[@intFromEnum(posix.V.TIME)] = 0;

        try posix.tcsetattr(stdin_fd, .FLUSH, raw);

        const stdout = std.io.getStdOut();
        // Enter alternate screen, hide cursor, clear screen, move home
        try stdout.writeAll("\x1b[?1049h\x1b[?25l\x1b[2J\x1b[H");

        return Term{
            .orig_termios = orig,
            .stdout = stdout,
        };
    }

    pub fn deinit(self: *Term) void {
        // Show cursor + leave alternate screen
        self.stdout.writeAll("\x1b[?25h\x1b[?1049l") catch {};
        posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, self.orig_termios) catch {};
    }

    pub fn size(self: *Term) Size {
        var ws: winsize = undefined;
        const rc = posix.system.ioctl(self.stdout.handle, TIOCGWINSZ, @intFromPtr(&ws));

        if (rc != 0 or ws.col == 0 or ws.row == 0) {
            // Fallback if ioctl fails
            return .{ .rows = 24, .cols = 80 };
        }
        return .{ .rows = ws.row, .cols = ws.col };
    }

    pub fn pollKey(self: *Term, timeout_ms: i32) !?Key {
        _ = self; // currently unused

        var fds = [_]posix.pollfd{
            .{
                .fd = posix.STDIN_FILENO,
                .events = POLLIN,
                .revents = 0,
            },
        };

        const n = posix.poll(&fds, timeout_ms) catch return null;
        if (n == 0) return null;

        var buf: [8]u8 = undefined;
        const len = posix.read(posix.STDIN_FILENO, &buf) catch return null;
        if (len == 0) return null;

        return parseKey(buf[0..len]);
    }

    pub fn write(self: *Term, bytes: []const u8) !void {
        try self.stdout.writeAll(bytes);
    }
};

fn parseKey(buf: []const u8) Key {
    if (buf.len == 1) {
        return switch (buf[0]) {
            'q', 'Q' => .quit,
            0x1b => .quit, // bare ESC
            else => .none,
        };
    }

    // CSI sequences: ESC [
    if (buf.len >= 3 and buf[0] == 0x1b and buf[1] == '[') {
        return switch (buf[2]) {
            'A' => .up,
            'B' => .down,
            '5' => .page_up, // ESC [ 5 ~
            '6' => .page_down, // ESC [ 6 ~
            else => .none,
        };
    }

    return .none;
}
