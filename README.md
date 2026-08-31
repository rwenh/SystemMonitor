# system-monitor (Zig port)

A from-scratch Zig reimplementation of the Rust `system-monitor` TUI. Zig has
no equivalent of `sysinfo`, `ratatui`/`crossterm`, `tokio`, or `serde`+`toml`,
so this isn't a syntax transliteration — the OS-facing pieces are rewritten
against Linux's `/proc` filesystem and raw terminal control directly.

## Requirements

- **Zig 0.14.x** (built and tested against 0.14.1 specifically).
- **Linux.** All system-data collection goes through `/proc`; there's no
  macOS or Windows backend. Porting further would mean adding
  `sysctl`-based collectors for macOS and WMI/PDH-based ones for Windows —
  a genuinely separate effort, not a small tweak.

### Why pin to 0.14.x instead of the latest Zig?

The current stable release, 0.16.0 (April 2026), shipped a sweeping
rewrite ("I/O as an Interface") that threads an `Io` instance through
essentially every file, process, and even random-number operation, on top
of 0.15's earlier `std.io.Writer`/`Reader` overhaul ("Writergate"). Both
are recent enough, and large enough, that I couldn't write against them
reliably without a compiler to check my work against — even Zig's own
release notes describe parts of the new interface as experimental. 0.14.1
is the last release before that rewrite: stable, thoroughly documented,
and what most existing Zig code and tutorials still target. If you want
this on 0.16+, the diff is substantial (`Io` params on most calls in
`term.zig`, `config.zig`, and the collectors) — happy to help with that
migration as a separate pass if you'd like it.

## Build & run

```sh
zig build run
```

or build then run separately:

```sh
zig build
./zig-out/bin/system-monitor
```

Press `q` or `Esc` to quit, `↑`/`↓` to move the process selection,
`PgUp`/`PgDn` to jump by 10.

## What I actually verified

I don't have a way to hand you code I merely believe compiles — I got a
real Zig 0.14.1 toolchain running in my sandbox (the `ziglang` PyPI
package, which bundles official release binaries) and used it:

- **`zig build` succeeds** with no errors or warnings.
- **Every collector ran against this sandbox's real `/proc`** and returned
  sane values — including watching CPU% correctly jump to ~100% and a
  `yes` process correctly rise to the top of the process table when I ran
  one as a synthetic load, which confirms the delta-based CPU sampling
  (see below) is actually computing the right thing, not just compiling.
- **The full interactive binary ran end-to-end** attached to a real
  pseudo-terminal (Python's `pty` module): raw mode, alternate screen,
  colors, the Unicode gauge/box characters, the process table, three
  ticks at the correct ~1-second cadence, `q` correctly quitting, and the
  terminal being cleanly restored afterward (cursor shown, alternate
  screen exited) — all confirmed from the captured raw output.
- **The config file load → edit → reload round-trip** was tested directly,
  including comment lines.

`term.zig` (raw mode, polling, ioctl for terminal size) is the one file
most dependent on exact OS/libc behavior rather than pure logic — it's
kept isolated so if anything ever needs adjusting on a different machine,
the change stays contained to that one file.

## Layout

```
build.zig
src/
  main.zig              entry point, tick/input loop
  models.zig             data structs (→ models.rs)
  utils.zig               byte/percent formatting (→ utils.rs)
  controller.zig          process-list scroll state (→ controller.rs)
  config.zig               settings load/save (→ config/mod.rs)
  term.zig                  raw mode, alt screen, key polling (→ crossterm)
  ui.zig                    frame rendering (→ ui/mod.rs, ratatui)
  collector/
    collector.zig            aggregates the sub-collectors (→ collector/mod.rs)
    cpu.zig, memory.zig, disk.zig, network.zig, process.zig
```

## Rust → Zig mapping

| Rust crate / file        | Zig approach |
|---------------------------|--------------|
| `sysinfo`                 | Direct `/proc` parsing: `/proc/stat`, `/proc/meminfo`, `/proc/net/dev`, `/proc/[pid]/{stat,comm,status}`. Disk space shells out to `df -P -k` (see `disk.zig` for why, not a syscall). |
| `ratatui` + `crossterm`   | `term.zig` (raw `std.posix` termios/poll/ioctl) + `ui.zig` (hand-written ANSI rendering — text gauges instead of ratatui's bordered-box widgets). |
| `tokio`                   | None needed. The original's `tokio::select!` between a tick and a 10ms input-poll sleep becomes a plain loop in `main.zig` that checks elapsed time each iteration — same two branches, sequenced instead of raced. |
| `serde` + `toml`          | A small hand-rolled parser/writer in `config.zig` for the two known fields. The file it writes is still valid basic TOML. |
| `anyhow` / `thiserror`    | Zig's built-in error unions; no crate needed. |

## Deliberate deviations from the original

I kept this a faithful port by default, but flagged (rather than silently
fixed) a couple of things:

- **`process_limit` is actually used.** In the Rust version, `config.rs`
  defines `process_limit` (default 15) but `ui/mod.rs`'s
  `render_processes` hardcodes `.take(15)` instead of reading it — the
  setting was loaded but never wired up. `ui.zig` reads it from
  `Settings`. Since the default is also 15, behavior is identical unless
  you actually change the setting. If you want to match the original's
  hardcoded-15 exactly, pass `15` instead of `settings.process_limit` in
  `main.zig`.
- **CPU sampling no longer blocks.** The original's `cpu.rs` sleeps 200ms
  *inside every `collect()` call* to get two samples far enough apart
  (that's how `sysinfo`'s refresh works). `cpu.zig` instead keeps the
  previous `/proc/stat` sample across ticks and diffs against it each
  time — the same technique `top`/`htop` use — so collection never blocks.
  Only visible effect: CPU% reads 0% on the very first frame instead of
  after a 200ms delay.
- **Disk targets `/` explicitly.** The original takes whatever disk
  `sysinfo` happens to enumerate first, which depends on OS-reported
  ordering. `disk.zig` targets the root filesystem by name instead —
  change `DiskCollector.mount_point` if you want a different one.

Everything else — including things I *didn't* fix, like network stats
being collected but never shown in the UI, and Ctrl+C not quitting the
app because raw mode disables `ISIG` and nothing handles it explicitly —
matches the original on purpose.

## Config file

`$XDG_CONFIG_HOME/system-monitor/config.toml`, falling back to
`$HOME/.config/system-monitor/config.toml` — same location logic as the
original's `dirs::config_dir()` on Linux. Created with defaults
(`update_ms = 1000`, `process_limit = 15`) on first run if missing.
