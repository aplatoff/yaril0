//

const std = @import("std");
const value = @import("value.zig");
const heap = @import("heap.zig");

const Allocator = std.mem.Allocator;
const Value = value.Value;
const ValueError = value.ValueError;

const Heap = heap.Heap;

const VALUES_BUFFER_SIZE = 1024;
const STACK_SIZE = 128;
const MAX_STRING_SIZE = 1024;

pub const Parser = struct {
    values: [VALUES_BUFFER_SIZE]Value = undefined,
    vp: usize = 0,
    stack: [STACK_SIZE]usize = undefined,
    sp: usize = 0,

    fn append(self: *Parser, val: Value) ValueError!void {
        if (self.vp == VALUES_BUFFER_SIZE) return ValueError.OutOfMemory;
        self.values[self.vp] = val;
        self.vp += 1;
    }

    pub fn parse(h: *Heap, bytes: []const u8) ValueError!void {
        var parser = Parser{};
        var it = std.unicode.Utf8Iterator{ .bytes = bytes, .i = 0 };
        while (it.nextCodepointSlice()) |slice| {
            if (std.ascii.isDigit(slice[0])) {
                var val: i32 = slice[0] - '0';
                while (it.nextCodepointSlice()) |s| {
                    if (!std.ascii.isDigit(s[0])) {
                        if (std.ascii.isWhitespace(slice[0])) break;
                        return ValueError.InvalidValue;
                    }
                    val = val * 10 + (s[0] - '0');
                }
                try parser.append(Value.initInteger(val));
                continue;
            }
            if (std.ascii.isWhitespace(slice[0])) continue;
            if (slice[0] == '"') {
                var string: [MAX_STRING_SIZE]u8 = undefined;
                var len: usize = 0;
                while (it.nextCodepointSlice()) |s| {
                    if (s[0] == '"') break;
                    if (len + s.len >= MAX_STRING_SIZE) return ValueError.OutOfMemory;
                    @memcpy(string[len .. len + s.len], s);
                    len += s.len;
                }
                const ptr = try heap.Array.allocate(h, value.Byte, len);
                @memcpy(ptr, string[0..len]);
                std.debug.print("string: {s}\n", .{ptr});
                continue;
            }
        }
    }
};
