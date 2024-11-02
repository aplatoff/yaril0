const std = @import("std");

const Allocator = std.mem.Allocator;

pub const ValueError = error{ TypeMismatch, InvalidValue, OutOfMemory };

const HeapPointer = u32;

pub const ValueKind = u8;

pub fn Type(comptime kind: ValueKind, comptime T: type) type {
    return packed struct {
        const Kind = kind;
        const Type = T;
        const Self = @This();

        value: T,

        pub inline fn init(value: T) Self {
            return Self{
                .value = value,
            };
        }

        pub inline fn val(self: Self) T {
            return self.value;
        }
    };
}

pub const None = Type(0, void);
pub const U8 = Type(1, u8);
pub const I32 = Type(2, i32);

pub const Array = Type(3, HeapPointer);

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

        const Header = if (size < 0x80) Array2 else Array4;
        const padding = @max(0, @alignOf(Item) - @sizeOf(Header));
        const header_size = @sizeOf(Header) + padding;
        comptime {
            std.debug.assert(@mod(header_size, @sizeOf(Item)) == 0);
        }
        const slot = try self.allocateSize(header_size + array_size);
        const header: *Header = @ptrCast(&self.memory[slot]);
        header.kind = T.Kind;
        if (size < 0x80) {
            header.len = @intCast(size);
        } else {
            const hi: u8 = @intCast(size >> 16);
            header.len = hi | 0x80;
            header.extra = @intCast(size);
        }
        const items: [*]Item = @ptrCast(&self.memory[slot]);
        const offset = header_size / @sizeOf(Item);
        @memcpy(items[offset..], values);
        return Array.init(slot);
    }

    pub inline fn open(self: *Heap, comptime T: type, array: Array) []const T.Type {
        const Item = T.Type;
        const slot = array.val();
        const header: *Array2 = @ptrCast(&self.memory[slot]);
        if (header.len & 0x80 == 0) {
            const padding = @max(0, @alignOf(T.Type) - @sizeOf(Array2));
            const header_size = @sizeOf(Array2) + padding;
            const offset = header_size / @sizeOf(Item);
            const items: [*]Item = @ptrCast(&self.memory[slot]);
            return items[offset .. offset + header.len];
        } else {
            @panic("not implemented");
        }
    }
};

pub const TYPES = [_]type{ &None, &U8, &I32 };

test "basic values" {
    const testing = std.testing;
    const int32 = I32.init(42);
    std.debug.print("int32: {d}\n", .{int32.val()});
    try testing.expectEqual(4, @sizeOf(I32));
    // const a = value.Value.initInteger(1);
    // const c = value.Value.initFloat(3.0);
    // try testing.expectEqual(a.toInteger(), 1);
    // try testing.expectEqual(c.toFloat(), 3.0);
    // try testing.expectEqual(a.toFloat(), 1.0);
    // try testing.expectEqual(c.toInteger(), 3);
}

test "heap values" {
    const testing = std.testing;
    var heap = try Heap.init(std.testing.allocator, 1024 * 1024);
    defer heap.deinit(std.testing.allocator);

    const a1 = try heap.allocateSize(100);
    try testing.expectEqual(1, a1);

    const arr = try heap.allocate(I32, &[_]i32{ 1, 2, 3, 4, 5 });
    std.debug.print("arr: {any}\n", .{arr});
    std.debug.print("arr: {any}\n", .{heap.open(I32, arr)});

    // try parser.Parser.parse(&theap, " \"hello\" ");
}
