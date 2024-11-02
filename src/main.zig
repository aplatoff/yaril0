//

const std = @import("std");
const yar = @import("root.zig");

const Allocator = std.mem.Allocator;

fn work(allocator: Allocator) !void {
    var theap = try yar.heap.Heap.init(allocator, 1024 * 1024);
    defer theap.deinit(allocator);

    const arr = try yar.heap.Array.allocate(&theap, yar.value.IntegerType, 10);
    std.debug.print("arr: {d}\n", .{arr});
}

pub fn main() !void {
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    try work(std.heap.page_allocator);

    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    // try bw.flush(); // don't forget to flush!
}
