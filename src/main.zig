//! Memory strategy: one long-lived GeneralPurposeAllocator for things that
//! must survive the whole program (the process collector's HashMap), and
//! one ArenaAllocator that's reset at the top of every tick for everything
//! a single SystemMetrics snapshot needs (strings, the process slice).
//! "everything from this tick disappears at once" ergonomics without needing a free/
//! deinit call for every string field.
const std = @import("std");
const config = @import("config.zig");
const controller_mod = @import("controller.zig");
const collector_mod = @import("collector/collector.zig");
const ui_mod = @import("ui.zig");
const term = @import("term.zig");

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    const settings = config.Settings.load(gpa) catch config.Settings.default();

    var terminal = try term.Term.init();
    defer terminal.deinit();

    var collector = collector_mod.Collector.init(gpa);
    defer collector.deinit();

    var controller = controller_mod.Controller{};
    var ui = ui_mod.Ui.init(gpa);
    defer ui.deinit();

    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();

    const update_ms: i64 = @intCast(settings.update_ms);
    var last_tick: i64 = std.time.milliTimestamp() - update_ms;

    while (true) {
        const now = std.time.milliTimestamp();

        if (now - last_tick >= update_ms) {
            _ = arena_state.reset(.retain_capacity);
            const metrics = try collector.collectAll(arena_state.allocator());
            try ui.render(&terminal, &metrics, &controller, settings.process_limit);
            last_tick = now;
        } else if (try terminal.pollKey(10)) |key| {
            switch (key) {
                .quit => return,
                .up => controller.scrollUp(),
                .down => controller.scrollDown(),
                .page_up => controller.pageUp(),
                .page_down => controller.pageDown(),
                .none => {},
            }
        }
    }
}
