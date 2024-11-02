//
const std = @import("std");
const val = @import("value.zig");

const Allocator = std.mem.Allocator;

const Value = val.Value;
const ValueKind = val.ValueKind;
const ValueType = val.ValueType;
const HeapPointer = val.HeapPointer;
const ValueError = val.ValueError;

pub const ObjectType = enum(u2) {
    array,
    block,
    mut_array,
    mut_block,
};

pub const HeapObject = packed struct {
    object_type: ObjectType, // 2 bits
    _padding: u30,
};

pub const Array = packed struct {
    object_type: ObjectType, // 2 bits
    typ: ValueKind, // 4 bits
    len: u10,

    pub inline fn allocate(heap: *Heap, comptime T: ValueType, size: usize) ValueError![]T.typ {
        const Item = T.typ;
        const Offset = if (@sizeOf(Item) > @sizeOf(Array)) Item else Array;
        const array_size = size * @sizeOf(Item);
        const header_size = @sizeOf(Offset);
        const slot = try heap.allocate(array_size + header_size);
        const array = heap.as(Array, slot);
        array.object_type = ObjectType.array;
        array.typ = T.kind;
        array.len = @intCast(size);
        const offsets: [*]Offset = @alignCast(@ptrCast(array));
        const ptr: [*]Item = @ptrCast(&offsets[1]);
        return ptr[0..size];
    }
};

pub const Heap = struct {
    const Slot = packed union {
        header: HeapObject,
        free_block: HeapPointer,
    };

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

    pub inline fn as(self: *Heap, comptime T: type, ptr: HeapPointer) *T {
        return @ptrCast(&self.memory[ptr]);
    }

    pub inline fn allocate(self: *Heap, size: usize) !HeapPointer {
        const size_class = getSizeClass(size);
        if (size_class == NUM_SIZE_CLASSES) return ValueError.OutOfMemory;
        const free_slot = self.free_lists[size_class];
        if (free_slot != 0) {
            self.free_lists[size_class] = self.memory[free_slot].free_block;
            return free_slot;
        } else {
            const slot = self.next;
            self.next += SIZE_SLOTS[size_class];
            if (self.next >= self.memory.len) return ValueError.OutOfMemory;
            return @intCast(slot);
        }
    }
};

test "sizes" {
    try std.testing.expectEqual(4, @sizeOf(Heap.Slot));
}
