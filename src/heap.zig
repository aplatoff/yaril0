//
const std = @import("std");
const val = @import("value.zig");

const Allocator = std.mem.Allocator;

const ValueKind = val.ValueKind;
const ValueError = val.ValueError;
const Type = val.Type;

pub const HeapPointer = u32;

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

    pub inline fn slotPtr(self: *Heap, comptime T: type, slot: HeapPointer) T {
        return @ptrCast(&self.memory[slot]);
    }

    pub inline fn allocate(self: *Heap, size: usize) ValueError!HeapPointer {
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
};
