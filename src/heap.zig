//
const std = @import("std");
const val = @import("value.zig");

const Allocator = std.mem.Allocator;

const ValueKind = val.ValueKind;
const ValueError = val.ValueError;
const Type = val.Type;

const HeapPointer = u32;
pub const Array = Type(1, HeapPointer);

pub const Heap = struct {
    const Slot = HeapPointer;

    const SIZE_CLASSES = [_]usize{ 8, 12, 16, 24, 32, 64, 128, 256, 512, 1024 };
    const NUM_SIZE_CLASSES = SIZE_CLASSES.len;

    fn slotSizes(comptime arr: []const usize) [arr.len]usize {
        var result: [arr.len]usize = undefined;
        comptime {
            for (arr, 0..) |item, index| result[index] = item / @sizeOf(Slot);
        }
        return result;
    }

    const SIZE_SLOTS = slotSizes(&SIZE_CLASSES);

    inline fn getSizeClass(size: usize) usize {
        for (SIZE_CLASSES, 0..) |class_size, index| {
            if (size <= class_size) return index;
        }
        return NUM_SIZE_CLASSES;
    }

    memory: []Slot,
    next: usize,
    free_lists: [NUM_SIZE_CLASSES]HeapPointer,

    pub fn init(allocator: Allocator, size: usize) ValueError!Heap {
        if (size < 16) return ValueError.OutOfMemory;
        const memory = allocator.alloc(Slot, size / @sizeOf(Slot)) catch return ValueError.OutOfMemory;

        return Heap{
            .memory = memory,
            .next = 1,
            .free_lists = .{0} ** NUM_SIZE_CLASSES,
        };
    }

    pub fn deinit(self: *Heap, allocator: Allocator) void {
        allocator.free(self.memory);
    }

    inline fn allocateSize(self: *Heap, size: usize) !HeapPointer {
        const size_class = getSizeClass(size);
        if (size_class == NUM_SIZE_CLASSES) return ValueError.OutOfMemory;
        const free_slot = self.free_lists[size_class];
        if (free_slot != 0) {
            self.free_lists[size_class] = self.memory[free_slot];
            return free_slot;
        } else {
            const slot = self.next;
            self.next += SIZE_SLOTS[size_class];
            if (self.next >= self.memory.len) return ValueError.OutOfMemory;
            return @intCast(slot);
        }
    }

    const Array2 = packed struct { kind: ValueKind, len: u8 };
    const Array4 = packed struct { kind: ValueKind, len: u8, extra: u16 };

    pub inline fn allocate(self: *Heap, comptime T: type, values: []const T.Type) ValueError!Array {
        const Item = T.Type;
        const size = values.len;
        const array_size = size * @sizeOf(Item);

        if (size < 0x80) {
            const header_size = @sizeOf(Array2);
            const padding = @max(0, @alignOf(Item) - header_size);
            const offset = header_size + padding;
            comptime {
                std.debug.assert(@mod(offset, @sizeOf(Item)) == 0);
            }
            const slot = try self.allocateSize(offset + array_size);

            const header: *Array2 = @ptrCast(&self.memory[slot]);
            header.kind = T.Kind;
            header.len = @intCast(size);

            const items: [*]Item = @ptrCast(&self.memory[slot]);
            @memcpy(items[offset / @sizeOf(Item) ..], values);
            return Array.init(slot);
        } else {
            const header_size = @sizeOf(Array4);
            const padding = @max(0, @alignOf(Item) - header_size);
            const offset = header_size + padding;
            comptime {
                std.debug.assert(@mod(header_size + padding, @sizeOf(Item)) == 0);
            }
            const slot = try self.allocateSize(offset + array_size);

            const header: *Array4 = @ptrCast(&self.memory[slot]);
            const hi: u8 = @intCast(size >> 16);
            header.kind = T.Kind;
            header.len = hi | 0x80;
            header.extra = @intCast(size);

            const items: [*]Item = @ptrCast(&self.memory[slot]);
            @memcpy(items[offset / @sizeOf(Item) ..], values);
            return Array.init(slot);
        }
    }

    pub inline fn open(self: *Heap, comptime T: type, array: Array) []const T.Type {
        const Item = T.Type;
        const slot = array.val();
        const header: *Array2 = @ptrCast(&self.memory[slot]);
        if (header.len & 0x80 == 0) {
            const padding = @max(0, @alignOf(Item) - @sizeOf(Array2));
            const header_size = @sizeOf(Array2) + padding;
            const offset = header_size / @sizeOf(Item);
            const items: [*]Item = @ptrCast(&self.memory[slot]);
            return items[offset .. offset + header.len];
        } else {
            @panic("not implemented");
        }
    }
};
