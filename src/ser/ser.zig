//! Serialization framework.

/// A namespace containing serialization-specific types and functions.
pub const ser = struct {
    ////////////////////////////////////////////////////////////////////////////////
    // Types
    ////////////////////////////////////////////////////////////////////////////////

    pub const Map = @import("interfaces/map.zig").Map;
    pub const Seq = @import("interfaces/seq.zig").Seq;
    pub const Structure = @import("interfaces/structure.zig").Structure;

    ////////////////////////////////////////////////////////////////////////////////
    // Namespaces
    ////////////////////////////////////////////////////////////////////////////////

    /// Serialization blocks provided by Getty.
    pub const blocks = @import("blocks.zig");

    /// Constraints that can be used to perform compile-time validation for a
    /// type.
    pub const concepts = @import("concepts.zig");

    /// Functions that can be used to query, at compile-time, the properties of
    /// a type.
    pub const traits = @import("traits.zig");

    ////////////////////////////////////////////////////////////////////////////////
    // Functions
    ////////////////////////////////////////////////////////////////////////////////

    /// Returns serialization attributes for `T`. If none exist, `null` is
    /// returned.
    pub const getAttributes = @import("attributes.zig").getAttributes;

    ////////////////////////////////////////////////////////////////////////////////
    // Error Sets
    ////////////////////////////////////////////////////////////////////////////////

    pub const Error = @import("error.zig").Error;
};

comptime {
    @import("std").testing.refAllDecls(ser);
}
