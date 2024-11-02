//

const std = @import("std");
const val = @import("value.zig");
const heap = @import("heap.zig");

const Allocator = std.mem.Allocator;
const ValueKind = val.ValueKind;
const ValueError = val.ValueError;
const Heap = heap.Heap;
const Array = heap.Array;

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

        pub fn allocate(self: *Self, hp: *Heap) ValueError!Array {
            defer self.values.deinit();
            return hp.allocate(T, self.values.items);
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
