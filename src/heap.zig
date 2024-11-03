//
const std = @import("std");
const val = @import("value.zig");

const Allocator = std.mem.Allocator;

const ValueKind = val.ValueKind;
const ValueError = val.ValueError;
const Type = val.Type;

pub const HeapPointer = u32; // used as index into memory array
pub const Slot = u32; // memory slot mininal size and alignement
pub const SizeClass = u4;

pub const Heap = struct {
    const SizeClasses = 16;
    const LargePoolSize = 0x1000;
    const Sizes: @Vector(SizeClasses, u16) =
        .{ 0x0008, 0x000c, 0x0010, 0x0018, 0x0020, 0x0030, 0x0040, 0x0060, 0x0080, 0x00c0, 0x0100, 0x0180, 0x0200, 0x0400, 0x0800, LargePoolSize };
    const SlotSizes: [SizeClasses]usize = Sizes / @as(@Vector(SizeClasses, u16), @splat(@sizeOf(Slot)));

    inline fn getSizeClass(size: usize) SizeClass {
        const vec = @as(@Vector(SizeClasses, u16), @splat(@intCast(size)));
        const cmp = Sizes > vec;
        const mask = @as(u16, @bitCast(cmp));
        const class = @ctz(mask);
        std.debug.assert(class < SizeClasses);
        return @intCast(@ctz(mask));
    }

    memory: []Slot,
    next: usize,
    free_lists: [SizeClasses]HeapPointer,

    pub fn init(memory: []Slot) Heap {
        return Heap{
            .memory = memory,
            .next = 1,
            .free_lists = .{0} ** SizeClasses,
        };
    }

    pub fn debugDump(self: *Heap) void {
        for (0..self.next) |slot| {
            std.debug.print("{x} {x}\n", .{ slot, self.memory[slot] });
        }
    }

    pub inline fn slotPtr(self: *Heap, comptime T: type, slot: HeapPointer) T {
        return @ptrCast(&self.memory[slot]);
    }

    pub inline fn allocate(self: *Heap, size: usize) ValueError!HeapPointer {
        if (size > LargePoolSize) return ValueError.OutOfMemory;
        const size_class = getSizeClass(size);
        const free_slot = self.free_lists[size_class];
        if (free_slot != 0) {
            self.free_lists[size_class] = self.memory[free_slot];
            return free_slot;
        } else {
            const slot = self.next;
            self.next += SlotSizes[size_class];
            if (self.next >= self.memory.len) return ValueError.OutOfMemory;
            return @intCast(slot);
        }
    }
};
