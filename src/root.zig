const std = @import("std");

const value = @import("value.zig");
const heap = @import("heap.zig");
const block = @import("block.zig");
const parser = @import("parser.zig");

pub const Type = value.Type;
pub const Heap = heap.Heap;
pub const ArrayOf = block.ArrayOf;
pub const BlockType = block.BlockType;
pub const BlockIterator = block.BlockIterator;

pub const parse = parser.parse;

pub const None = value.None;

pub const Array = block.Array;
pub const Block = block.Block;

pub const U8 = value.U8;
pub const I32 = value.I32;
pub const U32 = value.U32;

test "basic values" {
    const testing = std.testing;
    const int32 = I32.init(42);
    std.debug.print("int32: {d}\n", .{int32.val()});
    try testing.expectEqual(4, @sizeOf(I32));
}

test "heap values" {
    const mem = try std.testing.allocator.alloc(u32, 65536);
    defer std.testing.allocator.free(mem);
    var heap_obj = Heap.init(mem);
    const hp = &heap_obj;

    const ai32 = ArrayOf(I32);
    const arr = try ai32.allocate(hp, &[_]i32{ 1, 2, 3, 4, 5 }, 0);
    std.debug.print("arr: {any}\n", .{arr});
    std.debug.print("arr: {any}\n", .{arr.items(hp)});
    // hp.debugDump();
}

test "parser" {
    const mem = try std.testing.allocator.alloc(u32, 65536);
    defer std.testing.allocator.free(mem);
    var heap_obj = Heap.init(mem);
    const hp = &heap_obj;

    const p = try parse(hp, " \"hello!!!\" ");
    std.debug.print("p: {any}\n", .{p});
    hp.debugDump();
}

test "blocks" {
    const mem = try std.testing.allocator.alloc(u32, 65536);
    defer std.testing.allocator.free(mem);
    var heap_obj = Heap.init(mem);
    const hp = &heap_obj;

    const b = try BlockType.allocate0(hp);
    std.debug.print("b: {any}\n", .{b});
    // hp.debugDump();

    try b.appendItem(hp, I32, 31234);
    try b.appendItem(hp, I32, -555);
    try b.appendItem(hp, U8, 234);
    try b.appendItem(hp, U8, 1);
    try b.appendItem(hp, U32, 0x777);
    try b.appendItem(hp, U32, 0xcc);

    // hp.debugDump();

    var it = BlockIterator.init(hp, b.val());
    while (it.next()) {
        std.debug.print("it: {any}: {any}\n", .{ it.kind(), it.value() });
    }
}
