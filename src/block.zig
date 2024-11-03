//

const std = @import("std");
const val = @import("value.zig");
const heap = @import("heap.zig");

const Allocator = std.mem.Allocator;
const ValueKind = val.ValueKind;
const ValueError = val.ValueError;
const Heap = heap.Heap;
const Array = heap.Array;

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
                const slot_ptr = hp.slotPtr(slot);

                const header: *Array2 = @ptrCast(slot_ptr);
                header.kind = T.Kind;
                header.len = @intCast(size);

                const items: [*]Item = @ptrCast(slot_ptr);
                @memcpy(items[offset / @sizeOf(Item) ..], values);
                return init(Array.init(slot));
            } else {
                const padding = @max(0, @alignOf(Item) - @sizeOf(Array4));
                const offset = @sizeOf(Array4) + padding;
                comptime {
                    std.debug.assert(@mod(@sizeOf(Array4) + padding, @sizeOf(Item)) == 0);
                }
                const slot = try hp.allocate(offset + array_size);
                const slot_ptr = hp.slotPtr(slot);

                const header: *Array4 = @ptrCast(slot_ptr);
                const hi: u8 = @intCast(size >> 16);
                header.kind = T.Kind;
                header.len = hi | 0x80;
                header.extra = @intCast(size);

                const items: [*]Item = @ptrCast(slot_ptr);
                @memcpy(items[offset / @sizeOf(Item) ..], values);
                return init(Array.init(slot));
            }
        }

        pub fn open(self: Self, hp: *Heap) []const T.Type {
            const slot = self.value.val();
            const slot_ptr = hp.slotPtr(slot);
            const header: *Array2 = @ptrCast(slot_ptr);

            if (header.len & 0x80 == 0) {
                const padding = @max(0, @alignOf(Item) - @sizeOf(Array2));
                const offset = (@sizeOf(Array2) + padding) / @sizeOf(Item);
                const items: [*]Item = @ptrCast(slot_ptr);
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

const Ptr = struct {
    type: ValueKind,
    offset: u24,
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
};
