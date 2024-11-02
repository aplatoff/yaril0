//

const std = @import("std");
const val = @import("value.zig");

const Allocator = std.mem.Allocator;
const ValueKind = val.ValueKind;
const ValueError = val.ValueError;

const Ptr = struct {
    type: ValueKind,
    offset: u24,
};

const MAX_OFFSET = 1 << 24;

pub const Block = struct {
    ptrs: std.ArrayList(Ptr),
    values: std.ArrayList(u8),

    pub fn init(allocator: Allocator) Block {
        return Block{
            .ptrs = std.ArrayList(Ptr).init(allocator),
            .values = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Block) void {
        self.ptrs.deinit();
        self.values.deinit();
    }

    pub inline fn append(self: *Block, value: anytype) ValueError!void {
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
