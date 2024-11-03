//

const std = @import("std");
const yar = @import("root.zig");

const Allocator = std.mem.Allocator;

pub fn main() !void {
    const page_allocator = std.heap.page_allocator;
    const mem = try page_allocator.alloc(u32, 65536);
    defer page_allocator.free(mem);
    var heap_obj = yar.Heap.init(mem);
    const hp = &heap_obj;

    const ai32 = yar.ArrayOf(yar.I32);
    const arr = try ai32.allocate(hp, &[_]i32{ 1, 2, 3, 4, 5 });
    std.debug.print("arr: {any}\n", .{arr});
    std.debug.print("arr: {any}\n", .{arr.open(hp)});

    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const p = try yar.parse(allocator, hp, " \"hello\" ");
    std.debug.print("parsed: {any}\n", .{p});
}
