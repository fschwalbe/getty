const Visitor = @import("../../interface.zig").Visitor;

const VoidVisitor = @This();

pub usingnamespace Visitor(
    *VoidVisitor,
    serialize,
);

fn serialize(_: *VoidVisitor, value: anytype, serializer: anytype) @TypeOf(serializer).Error!@TypeOf(serializer).Ok {
    _ = value;

    return try serializer.serializeVoid();
}
