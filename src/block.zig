//

const std = @import("std");
const val = @import("value.zig");
const heap = @import("heap.zig");

const Allocator = std.mem.Allocator;
const ValueKind = val.ValueKind;
const ValueError = val.ValueError;
const Type = val.Type;

const Heap = heap.Heap;
const HeapPointer = heap.HeapPointer;

pub const Array = Type(1, HeapPointer);

const Array2 = packed struct { kind: ValueKind, len: u8 };
const Array4 = packed struct { kind: ValueKind, len: u8, extra: u16 };

pub fn ArrayOf(comptime T: type) type {
    return packed struct {
        const Item = T.Type;
        const Self = @This();

        value: Array,

        pub fn init(value: Array) Self {
            return Self{ .value = value };
        }

        pub fn allocate(hp: *Heap, values: []const Item) ValueError!Self {
            const size = values.len;
            const array_size = size * @sizeOf(Item);

            if (size < 0x80) {
                const padding = @max(0, @alignOf(Item) - @sizeOf(Array2));
                const offset = @sizeOf(Array2) + padding;
                comptime {
                    std.debug.assert(@mod(offset, @sizeOf(Item)) == 0);
                }
                const slot = try hp.allocate(offset + array_size);

                const header = hp.slotPtr(*Array2, slot);
                header.kind = T.Kind;
                header.len = @intCast(size);

                const items = hp.slotPtr([*]Item, slot);
                @memcpy(items[offset / @sizeOf(Item) ..], values);
                return init(Array.init(slot));
            } else {
                const padding = @max(0, @alignOf(Item) - @sizeOf(Array4));
                const offset = @sizeOf(Array4) + padding;
                comptime {
                    std.debug.assert(@mod(@sizeOf(Array4) + padding, @sizeOf(Item)) == 0);
                }
                const slot = try hp.allocate(offset + array_size);

                const header = hp.slotPtr(*Array4, slot);
                const hi: u8 = @intCast(size >> 16);
                header.kind = T.Kind;
                header.len = hi | 0x80;
                header.extra = @intCast(size);

                const items = hp.slotPtr([*]Item, slot);
                @memcpy(items[offset / @sizeOf(Item) ..], values);
                return init(Array.init(slot));
            }
        }

        pub fn open(self: Self, hp: *Heap) []const T.Type {
            const slot = self.value.val();
            const header = hp.slotPtr(*Array2, slot);

            if (header.len & 0x80 == 0) {
                const padding = @max(0, @alignOf(Item) - @sizeOf(Array2));
                const offset = (@sizeOf(Array2) + padding) / @sizeOf(Item);
                const items = hp.slotPtr([*]Item, slot);
                return items[offset .. offset + header.len];
            } else {
                @panic("not implemented");
            }
        }

        pub fn ptr(self: Self) Array {
            return self.value;
        }
    };
}

pub fn MutArray(comptime T: type) type {
    return struct {
        const Item = T.Type;
        const Self = @This();

        values: std.ArrayList(Item),

        pub fn init(allocator: Allocator) Self {
            return Self{ .values = std.ArrayList(Item).init(allocator) };
        }

        pub fn append(self: *Self, value: Item) ValueError!void {
            return self.values.append(value) catch return ValueError.OutOfMemory;
        }

        pub fn appendSlice(self: *Self, values: []const Item) ValueError!void {
            return self.values.appendSlice(values) catch return ValueError.OutOfMemory;
        }

        pub fn allocate(self: *Self, hp: *Heap) ValueError!ArrayOf(T) {
            defer self.values.deinit();
            return ArrayOf(T).allocate(hp, self.values.items);
        }
    };
}

const Ptr = packed struct {
    type: ValueKind,
    offset: u24,
};

pub const Block = Type(2, HeapPointer);

pub const BlockIterator = struct {
    ptr: [*]u8,
    len: usize,
    pos: usize,

    pub fn init(hp: *Heap, block: Block) BlockIterator {
        const slot = block.val();
        const ptr = hp.slotPtr([*]u8, slot);
        const slot_ptr = hp.slotPtr(*HeapPointer, slot);
        return BlockIterator{ .ptr = ptr, .len = slot_ptr.*, .pos = 0 };
    }

    pub inline fn next(self: *BlockIterator) bool {
        self.pos += 1;
        return self.pos <= self.len;
    }

    pub inline fn kind(self: BlockIterator) ValueKind {
        const ptrs: [*]Ptr = @alignCast(@ptrCast(&self.ptr[@sizeOf(HeapPointer)]));
        return ptrs[self.pos - 1].type;
    }

    pub inline fn value(self: BlockIterator) *u8 {
        const ptrs: [*]Ptr = @alignCast(@ptrCast(&self.ptr[@sizeOf(HeapPointer)]));
        const offset = ptrs[self.pos - 1].offset;

        const values_offset = @sizeOf(HeapPointer) + @sizeOf(Ptr) * self.len;
        return &self.ptr[values_offset + offset];
    }
};

pub const MutBlock = struct {
    const MAX_OFFSET = 1 << 24;

    ptrs: std.ArrayList(Ptr),
    values: std.ArrayList(u8),

    pub fn init(allocator: Allocator) MutBlock {
        return MutBlock{
            .ptrs = std.ArrayList(Ptr).init(allocator),
            .values = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *MutBlock) void {
        self.ptrs.deinit();
        self.values.deinit();
    }

    pub inline fn append(self: *MutBlock, value: anytype) ValueError!void {
        const T = @TypeOf(value);
        const Item = T.Type;
        const len = self.values.items.len;
        const offset = std.mem.alignForward(usize, len, @alignOf(Item));
        if (offset + @sizeOf(Item) > MAX_OFFSET) return ValueError.OutOfMemory;
        const padding = offset - len;
        if (padding > 0) try self.values.appendNTimes(0, padding);
        try self.values.appendSlice(std.mem.asBytes(&value));
        try self.ptrs.append(Ptr{ .type = T.Kind, .offset = @intCast(offset) });
    }

    pub fn allocate(self: *MutBlock, hp: *Heap) ValueError!Block {
        defer self.deinit();

        const header_size = @sizeOf(HeapPointer);
        const len = self.ptrs.items.len;
        const ptrs_size = len * @sizeOf(Ptr);
        const values_size = self.values.items.len;

        const size = header_size + ptrs_size + values_size;
        const slot = try hp.allocate(size);

        const header = hp.slotPtr(*HeapPointer, slot);
        header.* = @intCast(len);
        const ptrs = hp.slotPtr([*]Ptr, slot);
        @memcpy(ptrs[1 .. len + 1], self.ptrs.items);
        const values = hp.slotPtr([*]u8, slot);
        @memcpy(values[header_size + ptrs_size ..], self.values.items);

        return Block.init(slot);
    }
};
