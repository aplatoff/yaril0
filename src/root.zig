const std = @import("std");
const testing = std.testing;

pub const value = @import("value.zig");
pub const heap = @import("heap.zig");

test "basic values" {
    try testing.expectEqual(8, @sizeOf(value.Value));
    const a = value.Value.initInteger(1);
    const c = value.Value.initFloat(3.0);
    try testing.expectEqual(a.toInteger(), 1);
    try testing.expectEqual(c.toFloat(), 3.0);
    try testing.expectEqual(a.toFloat(), 1.0);
    try testing.expectEqual(c.toInteger(), 3);
}

test "heap values" {
    var theap = try heap.Heap.init(std.testing.allocator, 1024 * 1024);
    defer theap.deinit(std.testing.allocator);

    const a1 = try theap.allocate(100);
    try testing.expectEqual(1, a1);

    const arr = try heap.Array.allocate(&theap, value.IntegerType, 10);
    std.debug.print("arr: {d}\n", .{arr});
}
