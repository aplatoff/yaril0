const std = @import("std");

const value = @import("value.zig");
const heap = @import("heap.zig");
const block = @import("block.zig");
const parser = @import("parser.zig");

pub const Type = value.Type;
pub const Heap = heap.Heap;
pub const MutBlock = block.MutBlock;
pub const ArrayOf = block.ArrayOf;
pub const parse = parser.parse;

pub const None = value.None;

pub const Array = block.Array;
pub const Block = block.Block;

pub const U8 = value.U8;
pub const I32 = value.I32;

pub const TYPES = [_]type{ &None, &Array, &Block, &U8, &I32 };

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
    const arr = try ai32.allocate(hp, &[_]i32{ 1, 2, 3, 4, 5 });
    std.debug.print("arr: {any}\n", .{arr});
    std.debug.print("arr: {any}\n", .{arr.open(hp)});

    const p = try parse(std.testing.allocator, hp, " \"hello\" ");
    std.debug.print("p: {any}\n", .{p});
}

test "block values" {
    var mb = MutBlock.init(std.testing.allocator);
    try mb.append(I32.init(35234));
    try mb.append(U8.init(234));
    try mb.append(I32.init(777));

    const mem = try std.testing.allocator.alloc(u32, 65536);
    defer std.testing.allocator.free(mem);
    var heap_obj = Heap.init(mem);
    const hp = &heap_obj;

    const b = try mb.allocate(hp);
    hp.debugDump();

    var it = block.BlockIterator.init(hp, b);
    while (it.next()) {
        std.debug.print("it: {any}: {any}\n", .{ it.kind(), it.value() });
    }
}
