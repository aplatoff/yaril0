//

const std = @import("std");
const value = @import("value.zig");
const heap = @import("heap.zig");

const ValueKind = value.ValueKind;
const ValueError = value.ValueError;
const Type = value.Type;
const Array = value.Array;
const Block = value.Block;

const U8 = value.U8;
const U32 = value.U32;

const Heap = heap.Heap;
const SizeClass = heap.SizeClass;

const ArrayHeader = packed struct {
    len: u19,
    mutable: bool,
    storage: SizeClass,
    kind: ValueKind,
};

const AppendResult = struct { pos: usize, new_array: ?Array };

pub fn ArrayOf(comptime T: type) type {
    return packed struct {
        const Item = T.Type;
        const Self = @This();

        const Offset = std.mem.alignForward(usize, @sizeOf(ArrayHeader), @alignOf(Item));
        const OffsetItems = Offset / @sizeOf(Item);

        value: Array,

        pub fn init(array: Array) Self {
            return Self{ .value = array };
        }

        pub fn val(self: Self) Array {
            return self.value;
        }

        fn size(length: usize) usize {
            return Offset + @sizeOf(Item) * length;
        }

        fn len(self: Self, hp: *Heap) usize {
            const slot = self.value.val();
            const header = hp.slotPtr(*ArrayHeader, slot);
            return @intCast(header.len);
        }

        pub fn allocate(hp: *Heap, values: []const Item, cap: usize) ValueError!Self {
            const alloc = try hp.allocate(@max(cap, size(values.len)));
            const slot = alloc.slot;

            const header = hp.slotPtr(*ArrayHeader, slot);
            header.len = @intCast(values.len);
            header.mutable = true;
            header.storage = alloc.class;
            header.kind = T.Kind;

            const items_ptr = hp.slotPtr([*]Item, slot);
            @memcpy(items_ptr[OffsetItems..], values);
            return init(Array.init(slot));
        }

        pub fn allocate0(hp: *Heap) ValueError!Self {
            const slot = try hp.allocate0(ArrayHeader, ArrayHeader{
                .len = 0,
                .mutable = true,
                .storage = 0,
                .kind = T.Kind,
            });
            return init(Array.init(slot));
        }

        pub inline fn append(self: *const Self, hp: *Heap, values: []const Item, alignment: usize) ValueError!AppendResult {
            const slot = self.value.val();
            const header = hp.slotPtr(*ArrayHeader, slot);
            if (!header.mutable) return ValueError.ImmutableValue;

            const length: usize = @intCast(header.len);
            const cur_size = size(length);
            const cur_size_aligned = std.mem.alignForward(usize, cur_size, alignment);
            const padding = cur_size_aligned - cur_size;
            // ensure padding alined with item size
            const padding_items = padding / @sizeOf(Item);
            const pos = length + padding_items;
            const new_size = cur_size_aligned + @sizeOf(Item) * values.len;

            const cap = heap.Sizes[header.storage];
            if (new_size > cap) {
                const items_ptr = hp.slotPtr([*]Item, slot);
                const alloc = try Self.allocate(hp, items_ptr[OffsetItems .. OffsetItems + length], new_size);
                const new_array = alloc.value;
                const new_array_header = hp.slotPtr(*ArrayHeader, new_array.val());
                const new_items: [*]Item = @constCast(@ptrCast(new_array_header));

                @memcpy(new_items[OffsetItems + pos ..], values);
                new_array_header.len = @intCast(pos + values.len);
                hp.freeClass(slot, header.storage);
                return .{ .pos = pos, .new_array = new_array };
            } else {
                const new_items: [*]Item = @constCast(@ptrCast(header));
                @memcpy(new_items[OffsetItems + pos ..], values);
                header.len = @intCast(pos + values.len);
                return .{ .pos = pos, .new_array = null };
            }
        }

        pub fn appendItem(self: *const Self, hp: *Heap, item: Item) ValueError!AppendResult {
            return self.append(hp, &[_]Item{item}, T.Align);
        }

        pub fn items(self: Self, hp: *Heap) []const T.Type {
            const slot = self.value.val();
            const header = hp.slotPtr(*ArrayHeader, slot);
            const items_ptr = hp.slotPtr([*]Item, slot);
            return items_ptr[OffsetItems .. OffsetItems + header.len];
        }
    };
}

const MaxOffset = 1 << 24;
const Offsets = packed union {
    data: packed struct { offset: u24, type: ValueKind },
    raw: u32,
};

pub const BlockIterator = struct {
    offsets: []const Offsets,
    values: []const u8,
    pos: usize,

    pub fn init(hp: *Heap, block: Block) BlockIterator {
        const header = hp.slotPtr(*BlockHeader, block.val());
        const values = ArrayOf(U8).init(header.values);
        const offsets = ArrayOf(U32).init(header.offsets);
        return BlockIterator{
            .offsets = @ptrCast(offsets.items(hp)),
            .values = @ptrCast(values.items(hp)),
            .pos = 0,
        };
    }

    pub fn next(self: *BlockIterator) bool {
        self.pos += 1;
        return self.pos <= self.offsets.len;
    }

    pub fn kind(self: BlockIterator) ValueKind {
        return self.offsets[self.pos - 1].data.type;
    }

    pub fn value(self: BlockIterator) *const u8 {
        const offset = self.offsets[self.pos - 1].data.offset;
        return &self.values[offset];
    }
};

const BlockHeader = struct {
    offsets: Array,
    values: Array,
}; // do not use packed, it will cause alignment issue

pub const BlockType = struct {
    const Self = @This();

    value: Block,

    pub fn init(block: Block) Self {
        return Self{ .value = block };
    }

    pub fn val(self: Self) Block {
        return self.value;
    }

    pub fn allocate0(hp: *Heap) ValueError!Self {
        const offsets = try ArrayOf(U32).allocate0(hp);
        const values = try ArrayOf(U8).allocate0(hp);

        const slot = try hp.allocate0(BlockHeader, BlockHeader{
            .offsets = offsets.val(),
            .values = values.val(),
        });
        return init(Block.init(slot));
    }

    pub inline fn append(self: *const BlockType, hp: *Heap, kind: ValueKind, bytes: []const u8, alignment: usize) ValueError!void {
        const header = hp.slotPtr(*BlockHeader, self.value.val());
        const values = ArrayOf(U8).init(header.values);
        const offsets = ArrayOf(U32).init(header.offsets);

        const values_append = try values.append(hp, bytes, alignment);
        if (values_append.new_array) |array| header.values = array;

        const offset = Offsets{ .data = .{ .offset = @intCast(values_append.pos), .type = kind } };
        const offsets_append = try offsets.append(hp, &[_]u32{offset.raw}, 1);
        if (offsets_append.new_array) |array| header.offsets = array;
    }

    pub fn appendItem(self: *const BlockType, hp: *Heap, comptime T: type, item: T.Type) ValueError!void {
        const bytes = std.mem.toBytes(item);
        return self.append(hp, T.Kind, &bytes, @alignOf(T.Type));
    }
};
