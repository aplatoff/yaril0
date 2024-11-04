//

const std = @import("std");
const value = @import("value.zig");
const block = @import("block.zig");
const heap = @import("heap.zig");

const ValueKind = value.ValueKind;
const ValueError = value.ValueError;
const Array = value.Array;
const Block = value.Block;
const Context = value.Context;

const U32 = value.U32;

const ArrayOf = block.ArrayOf;
const BlockType = block.BlockType;

const Heap = heap.Heap;

const LinearContextHeader = struct {
    keys: Array,
    values: Block,
};

pub const LinearContext = struct {
    comptime {
        std.debug.assert(@sizeOf(LinearContextHeader) == 8);
    }

    const Self = @This();

    context: Context,

    pub inline fn init(context: Context) Self {
        return Self{ .context = context };
    }

    pub inline fn val(self: Self) Context {
        return self.context;
    }

    pub fn allocate0(hp: *Heap) ValueError!Self {
        const keys = try ArrayOf(U32).allocate0(hp);
        const values = try BlockType.allocate0(hp);

        const slot = try hp.allocate0(LinearContextHeader, LinearContextHeader{
            .keys = keys.val(),
            .values = values.val(),
        });
        return init(Context.init(slot));
    }

    pub fn append(self: *const Self, hp: *Heap, key: u32, kind: ValueKind, bytes: []const u8, alignment: usize) ValueError!void {
        const header = hp.slotPtr(*LinearContextHeader, self.context.val());
        const keys = ArrayOf(U32).init(header.keys);
        const values = BlockType.init(header.values);

        try values.append(hp, kind, bytes, alignment);
        const key_append = try keys.appendItem(hp, U32, key);
        if (key_append.new_array) |array| header.keys = array;
    }

    pub fn appendItem(self: *const Self, hp: *Heap, key: u32, comptime T: type, item: T.Type) ValueError!void {
        return self.append(hp, key, T.kind, std.mem.toBytes(item), @alignOf(T.Type));
    }
};
