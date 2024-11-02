//
// const std = @import("std");

pub const ValueError = error{ TypeMismatch, InvalidValue, OutOfMemory };

pub const HeapPointer = u32;
pub const Symbol = HeapPointer;

pub const ValueKind = enum(u4) {
    none,
    heap_object,
    byte,
    integer,
    float,
    boolean,
    char,
    word,
    quote,
    set_word,
    get_word,
};

pub const ValueType = struct { kind: ValueKind, typ: type };

pub const Integer = ValueType{
    .kind = .integer,
    .typ = i32,
};

pub const Byte = ValueType{
    .kind = .byte,
    .typ = u8,
};

const AnyValue = packed union {
    heap_object: HeapPointer,
    byte: u8,
    integer: i32,
    float: f32,
    boolean: bool,
    char: u21,
    word: Symbol,
    quote: Symbol,
    set_word: Symbol,
    get_word: Symbol,
};

// Main value type as packed struct containing tag and data
pub const Value = packed struct {
    type: ValueKind,
    data: AnyValue,

    pub fn initInteger(value: i32) Value {
        return .{
            .data = .{ .integer = value },
            .type = .integer,
        };
    }

    pub fn initFloat(value: f32) Value {
        return .{
            .data = .{ .float = value },
            .type = .float,
        };
    }

    pub fn isInteger(self: Value) bool {
        return self.type == .integer;
    }

    pub fn isFloat(self: Value) bool {
        return self.type == .float;
    }

    pub fn asInteger(self: Value) ValueError!i32 {
        if (self.type != .integer) {
            return ValueError.TypeMismatch;
        }
        return self.data.integer;
    }

    pub fn asFloat(self: Value) ValueError!f32 {
        if (self.type != .float) {
            return ValueError.TypeMismatch;
        }
        return self.data.float;
    }

    pub fn toInteger(self: Value) ValueError!i32 {
        return switch (self.type) {
            .integer => self.data.integer,
            .float => @intFromFloat(self.data.float),
            .boolean => @intFromBool(self.data.boolean),
            else => ValueError.TypeMismatch,
        };
    }

    pub fn toFloat(self: Value) ValueError!f32 {
        return switch (self.type) {
            .integer => @floatFromInt(self.data.integer),
            .float => self.data.float,
            else => ValueError.TypeMismatch,
        };
    }
};
