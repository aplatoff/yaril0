//
// const std = @import("std");

pub const ValueError = error{
    TypeMismatch,
    InvalidValue,
    OutOfMemory,
    ImmutableValue,
};
pub const ValueKind = u8;

pub fn Type(comptime kind: ValueKind, comptime T: type) type {
    return packed struct {
        pub const Type = T;
        pub const Align = @alignOf(T);
        pub const Kind = kind;
        const Self = @This();

        value: T,

        pub fn init(value: T) Self {
            return Self{
                .value = value,
            };
        }

        pub fn val(self: Self) T {
            return self.value;
        }
    };
}

pub const RTTI = struct {
    toString: fn (value: *u8) []const u8,
};

fn noneToString(_: *u8) []const u8 {
    return "None";
}

const NoneRtti = RTTI{
    .toString = noneToString,
};

pub const None = Type(0, void);

pub const Address = u32;
pub const Array = Type(1, Address);
pub const Block = Type(2, Address);
pub const Context = Type(3, Address);

pub const U32 = Type(4, u32);
pub const I32 = Type(5, i32);

pub const U8 = Type(6, u8);
