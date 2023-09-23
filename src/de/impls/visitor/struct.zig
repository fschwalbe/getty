const std = @import("std");

const getAttributes = @import("../../attributes.zig").getAttributes;
const Ignored = @import("../../impls/seed/ignored.zig").Ignored;
const VisitorInterface = @import("../../interfaces/visitor.zig").Visitor;

pub fn Visitor(comptime Struct: type) type {
    return struct {
        const Self = @This();

        pub usingnamespace VisitorInterface(
            Self,
            Value,
            .{ .visitMap = visitMap },
        );

        const Value = Struct;

        fn visitMap(_: Self, ally: std.mem.Allocator, comptime Deserializer: type, map: anytype) Deserializer.Err!Value {
            @setEvalBranchQuota(10_000);

            const fields = comptime std.meta.fields(Value);
            const attributes = comptime getAttributes(Value, Deserializer);

            // Indicates whether or not unknown fields should be ignored.
            const ignore_unknown_fields = comptime blk: {
                if (attributes) |attrs| {
                    if (@hasField(@TypeOf(attrs), "Container")) {
                        const attr = attrs.Container;
                        const ignore = @hasField(@TypeOf(attr), "ignore_unknown_fields") and attr.ignore_unknown_fields;

                        if (ignore) break :blk true;
                    }
                }

                break :blk false;
            };

            // ComptimeStringMap does not support an empty key set, so we have
            // to handle that case separately.
            if (fields.len == 0) {
                while (try map.nextKey(ally, []const u8)) |_| {
                    switch (ignore_unknown_fields) {
                        true => _ = try map.nextValue(ally, Ignored),
                        false => return error.UnknownField,
                    }
                }
                return .{};
            }

            const skip_bit = @as(usize, 1) << (@bitSizeOf(usize) - 1);

            const KeyMap = comptime blk: {
                const count = count: {
                    var count: usize = 0;
                    for (fields) |field| {
                        count += 1;
                        if (attributes) |attrs| {
                            if (!@hasField(@TypeOf(attrs), field.name)) continue;
                            const attr = @field(attrs, field.name);
                            if (@hasField(@TypeOf(attr), "aliases")) count += attr.aliases.len;
                        }
                    }
                    break :count count;
                };

                var kvs: [count]struct { []const u8, usize } = undefined;
                var kv_i: usize = 0;
                for (fields, 0..) |field, field_i| {
                    const attrs = attrs: {
                        if (attributes) |attrs| {
                            if (@hasField(@TypeOf(attrs), field.name)) {
                                const attr = @field(attrs, field.name);
                                break :attrs attr;
                            }
                        }

                        kvs[kv_i] = .{ field.name, field_i };
                        kv_i += 1;
                        continue;
                    };

                    const value = if (@hasField(@TypeOf(attrs), "skip") and attrs.skip)
                        field_i | skip_bit
                    else
                        field_i;

                    const name = if (@hasField(@TypeOf(attrs), "rename")) attrs.rename else field.name;
                    kvs[kv_i] = .{ name, value };
                    kv_i += 1;

                    if (@hasField(@TypeOf(attrs), "aliases")) {
                        for (attrs.aliases) |alias| {
                            kvs[kv_i] = .{ alias, value };
                            kv_i += 1;
                        }
                    }
                }

                break :blk std.ComptimeStringMap(usize, kvs);
            };

            var structure: Value = undefined;
            var seen = [_]bool{false} ** fields.len;

            while (try map.nextKey(ally, []const u8)) |key| {
                const key_i = KeyMap.get(key) orelse {
                    // Handle any keys that didn't match any fields in the struct.
                    //
                    // If the "ignore_unknown_fields" attribute is set, we'll
                    // deserialize and discard its corresponding value. Note that
                    // unlike with the "skip" attribute, the validity of an unknown
                    // field is not checked.
                    switch (ignore_unknown_fields) {
                        true => _ = try map.nextValue(ally, Ignored),
                        false => return error.UnknownField,
                    }
                    continue;
                };
                const i = key_i & ~skip_bit;
                if (seen[i]) return error.DuplicateField;

                switch (i) {
                    inline 0...fields.len - 1 => |idx| {
                        const field = fields[idx];
                        if (field.is_comptime) {
                            @compileError("TODO: DESERIALIZATION OF COMPTIME FIELD");
                        }

                        const value = try map.nextValue(ally, field.type);

                        // Don't assign value to field if the "skip" attribute
                        // is set.
                        //
                        // Note that we still deserialize a value and check its
                        // validity (e.g., its type is correct), we just don't
                        // assign it to field.
                        if (key_i & skip_bit != 0) continue;

                        @field(structure, field.name) = value;
                        seen[i] = true;
                    },
                    else => unreachable,
                }
            }

            // Process any remaining, unassigned fields.
            inline for (fields, 0..) |field, i| {
                if (!seen[i]) blk: {
                    // Assign to field the value of the "default" attribute, if
                    // it is set.
                    if (attributes) |attrs| {
                        if (@hasField(@TypeOf(attrs), field.name)) {
                            const attr = @field(attrs, field.name);

                            if (@hasField(@TypeOf(attr), "default")) {
                                if (!field.is_comptime) {
                                    @field(structure, field.name) = attr.default;

                                    break :blk;
                                }
                            }
                        }
                    }

                    // Assign to field its default value if it exists and the
                    // "default" attribute is not set.
                    if (field.default_value) |default_ptr| {
                        if (!field.is_comptime) {
                            const default_value = @as(*const field.type, @ptrCast(@alignCast(default_ptr))).*;
                            @field(structure, field.name) = default_value;

                            break :blk;
                        }
                    }

                    // The field has not been assigned a value and does not
                    // have any default value, so return an error.
                    return error.MissingField;
                }
            }

            return structure;
        }
    };
}
