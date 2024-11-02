//
// const std = @import("std");

pub const ValueError = error{ TypeMismatch, InvalidValue, OutOfMemory };
pub const ValueKind = u8;

pub fn Type(comptime kind: ValueKind, comptime T: type) type {
    return packed struct {
        pub const Type = T;
        pub const Kind = kind;
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
