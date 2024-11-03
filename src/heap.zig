//
const std = @import("std");
const val = @import("value.zig");

const ValueKind = val.ValueKind;
const ValueError = val.ValueError;
const Type = val.Type;

pub const SizeClass = u4;
pub const NumClasses = 16;
const SmallObjectLimit = 0x1000;
pub const Sizes: [NumClasses]usize =
    .{ 0x0008, 0x000c, 0x0010, 0x0018, 0x0020, 0x0030, 0x0040, 0x0060, 0x0080, 0x00c0, 0x0100, 0x0180, 0x0200, 0x0400, 0x0800, SmallObjectLimit };

const SizeVector: @Vector(NumClasses, u16) = Sizes;
const SlotSizes: [NumClasses]usize = Sizes / @as(@Vector(NumClasses, u16), @splat(@sizeOf(Slot)));

pub inline fn sizeClass(size: usize) SizeClass {
    const vec = @as(@Vector(NumClasses, u16), @splat(@intCast(size)));
    const cmp = Sizes > vec;
    const mask = @as(u16, @bitCast(cmp));
    const class = @ctz(mask);
    std.debug.assert(class < NumClasses);
    return @intCast(@ctz(mask));
}

pub const HeapPointer = u32; // used as index into memory array
pub const HeapObject = packed struct {
    size: SizeClass,
    _padding: u28,
};

pub const Slot = packed union {
    next_free: HeapPointer,
    data: HeapObject,
};

const Allocation = struct { slot: HeapPointer, class: SizeClass };

pub const Heap = struct {
    memory: []Slot,
    next: usize,
    free_lists: [NumClasses]HeapPointer,

    pub fn init(memory: []u32) Heap {
        return Heap{
            .memory = @ptrCast(memory),
            .next = 1,
            .free_lists = .{0} ** NumClasses,
        };
    }

    pub fn debugDump(self: *Heap) void {
        std.debug.print("next: {d}\n", .{self.next});
        for (0..self.next) |slot| {
            std.debug.print("{x} {x}\n", .{ slot, self.memory[slot].next_free });
        }
    }

    pub fn slotPtr(self: *Heap, comptime T: type, slot: HeapPointer) T {
        return @ptrCast(&self.memory[slot]);
    }

    pub inline fn allocateClass(self: *Heap, class: SizeClass) ValueError!HeapPointer {
        const free_slot = self.free_lists[class];
        if (free_slot != 0) {
            self.free_lists[class] = self.memory[free_slot].next_free;
            return free_slot;
        }
        const slot = self.next;
        self.next += SlotSizes[class];
        if (self.next >= self.memory.len) return ValueError.OutOfMemory;
        return @intCast(slot);
    }

    pub fn allocate0(self: *Heap, comptime T: type, value: T) ValueError!HeapPointer {
        comptime std.debug.assert(@sizeOf(T) <= Sizes[0]);
        const slot = try self.allocateClass(0);
        const ptr: *T = @ptrCast(&self.memory[slot]);
        ptr.* = value;
        return slot;
    }

    pub inline fn allocate(self: *Heap, size: usize) ValueError!Allocation {
        if (size > SmallObjectLimit) @panic("large objects not supported");
        const class = sizeClass(size);
        return Allocation{ .slot = try self.allocateClass(class), .class = class };
    }

    pub inline fn reallocate(self: *Heap, slot: HeapPointer, class: SizeClass, new_size: usize) ValueError!Allocation {
        if (new_size > SmallObjectLimit) @panic("large objects not supported");
        const new_class = sizeClass(new_size);
        if (class == new_class) return Allocation{ .slot = slot, .class = class };

        const new_slot = try self.allocateClass(new_class);
        const size_in_slots = SlotSizes[class];

        const old_ptr = self.slotPtr([*]HeapObject, slot);
        const new_ptr = self.slotPtr([*]HeapObject, new_slot);

        @memcpy(new_ptr[0..size_in_slots], old_ptr[0..size_in_slots]);
        self.freeClass(slot, class);

        return Allocation{ .slot = new_slot, .class = new_class };
    }

    pub inline fn freeClass(self: *Heap, slot: HeapPointer, class: SizeClass) void {
        self.memory[slot].next_free = self.free_lists[class];
        self.free_lists[class] = slot;
    }
};
