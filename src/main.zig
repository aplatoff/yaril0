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

    const c = try yar.LinearContext.allocate0(hp);
    std.debug.print("context: {any}\n", .{c});
    try c.appendItem(hp, 0xCAFEBABE, yar.I32, 0x77778888);
    hp.debugDump();

    const p = try yar.parse(hp, " \"hello\" ");
    std.debug.print("parsed: {any}\n", .{p});
    hp.debugDump();
}
