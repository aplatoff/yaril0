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

pub const None = Type(0, void);

pub const U8 = Type(3, u8);
pub const I32 = Type(4, i32);
