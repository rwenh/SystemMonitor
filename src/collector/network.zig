//! Reads /proc/net/dev directly and sums cumulative totals (since boot)
//! across every listed interface, loopback included, matching the original's
//! `for (_, net) in &nets` which didn't filter anything either:
//! these are cumulative counters, not a rate - nothing in the UI renders.

const std = @import("std");
const models = @import("../models.zig");

pub const NetworkCollector = struct {
    pub fn init() NetworkCollector {
        return .{};
        }

        pub fn collect(self: *NetworkCollector, arena: std.mem.Allocator) !models.NetworkMetrics {
            _ = self;
            const content = std.fs.cwd().readFileAlloc(arena, "/proc/net/dev", 1 << 16) catch {
                  return models.NetworkMetrics{ .bytes_recv = 0, .bytes_sent = 0, .packets_recv = 0, .packets_sent = 0 };
                  };

                  var total_rx_bytes: u64 = 0;
                  var total_tx_bytes: u64 = 0;
                  var total_rx_packets: u64 = 0;
                  var total_tx_packets: u64 = 0;

                  var lines = std.mem.tokenizeScalar(u8, content, '\n');
                  _ = lines.next(); // "Inter-|     Receive ..." header line 1
                  _ = lines.next(); // " face |bytes    packets ..." header line 2

                  while (lines.next()) |line| {
                        // Format: " eth0: rx_bytes rx_packets rx_errs rx_drop rx_fifo
                        // rx_frame rx_compressed rx_multicast tx_bytes tx_packets ..."
                        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
                        var it = std.mem.tokenizeAny(u8, line[colon + 1 ..], " \t");

                        var vals: [16]u64 = [_]u64{0} ** 16;
                        var i: usize = 0;
                        while (it.next()) |tok| : (i += 1) {
                              if (i >= vals.len) break;
                              vals[i] = std.fmt.parseInt(u64, tok, 10) catch 0;
                              }

                              total_rx_bytes += vals[0];
                              total_rx_packets += vals[1];
                              total_tx_bytes += vals[8];
                              total_tx_packets += vals[9];
                        }

                        return models.NetworkMetrics{
                               .bytes_recv = total_rx_bytes,
                               .bytes_sent = total_tx_bytes,
                               .packets_recv = total_rx_packets,
                               .packets_sent = total_tx_packets,
                               };
                }
};
