//

const std = @import("std");
const value = @import("value.zig");
const heap = @import("heap.zig");
const block = @import("block.zig");

const ValueError = value.ValueError;
const Array = value.Array;
const Block = value.Block;

const Heap = heap.Heap;

const ArrayOf = block.ArrayOf;
const BlockType = block.BlockType;

pub fn parse(hp: *Heap, bytes: []const u8) ValueError!Block {
    const STACK_SIZE = 128;

    var stack: [STACK_SIZE]BlockType = undefined;
    const sp: usize = 0;
    stack[sp] = try BlockType.allocate0(hp);

    var it = std.unicode.Utf8Iterator{ .bytes = bytes, .i = 0 };
    while (it.nextCodepointSlice()) |slice| {
        if (std.ascii.isDigit(slice[0])) {
            var val: i32 = slice[0] - '0';
            while (it.nextCodepointSlice()) |s| {
                if (!std.ascii.isDigit(s[0])) {
                    if (std.ascii.isWhitespace(slice[0])) break;
                    return ValueError.InvalidValue;
                }
                val = val * 10 + (s[0] - '0');
            }
            try stack[sp].appendItem(hp, value.I32, val);
            continue;
        }

        if (std.ascii.isWhitespace(slice[0])) continue;

        if (slice[0] == '"') {
            var string = try ArrayOf(value.U8).allocate0(hp);
            while (it.nextCodepointSlice()) |s| {
                if (s[0] == '"') break;
                const append = try string.append(hp, s, 1);
                if (append.new_array) |array| string = ArrayOf(value.U8).init(array);
            }
            try stack[sp].appendItem(hp, Array, string.val().val());
            continue;
        }
    }

    return stack[sp].val();
}
