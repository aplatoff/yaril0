const std = @import("std");

const value = @import("value.zig");
const heap = @import("heap.zig");
const block = @import("block.zig");

pub const Type = value.Type;
pub const Heap = heap.Heap;
pub const Block = block.Block;

pub const None = Type(0, void);
pub const Array = heap.Array;
pub const U8 = Type(2, u8);
pub const I32 = Type(3, i32);

pub const TYPES = [_]type{ &None, &Array, &U8, &I32 };

test "basic values" {
    const testing = std.testing;
    const int32 = I32.init(42);
    std.debug.print("int32: {d}\n", .{int32.val()});
    try testing.expectEqual(4, @sizeOf(I32));
}

test "heap values" {
    var theap = try Heap.init(std.testing.allocator, 1024 * 1024);
    defer theap.deinit(std.testing.allocator);

    const arr = try theap.allocate(I32, &[_]i32{ 1, 2, 3, 4, 5 });
    std.debug.print("arr: {any}\n", .{arr});
    std.debug.print("arr: {any}\n", .{theap.open(I32, arr)});

    // try parser.Parser.parse(&theap, " \"hello\" ");
}

test "block values" {
    var b = Block.init(std.testing.allocator);
    defer b.deinit();
    try b.append(I32.init(35234));
    try b.append(U8.init(234));
    try b.append(I32.init(777));
}
