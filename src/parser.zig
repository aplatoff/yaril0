//

const std = @import("std");
const value = @import("value.zig");
const heap = @import("heap.zig");
const block = @import("block.zig");

const Allocator = std.mem.Allocator;
const ValueError = value.ValueError;
const Heap = heap.Heap;

const Block = block.Block;
const MutBlock = block.MutBlock;
const MutArray = block.MutArray;

pub fn parse(allocator: Allocator, hp: *Heap, bytes: []const u8) ValueError!Block {
    const STACK_SIZE = 128;

    var stack: [STACK_SIZE]MutBlock = undefined;
    const sp: usize = 0;
    stack[sp] = MutBlock.init(allocator);

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
            try stack[sp].append(value.I32.init(val));
            continue;
        }

        if (std.ascii.isWhitespace(slice[0])) continue;

        if (slice[0] == '"') {
            var string = MutArray(value.U8).init(allocator);
            while (it.nextCodepointSlice()) |s| {
                if (s[0] == '"') break;
                try string.appendSlice(s);
            }
            const arr = try string.allocate(hp);
            try stack[sp].append(arr.ptr());
            continue;
        }
    }

    return try stack[sp].allocate(hp);
}
