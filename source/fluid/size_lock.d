/// Size locking allows placing restrictions on the size of a node. Using the `SizeLock` node
/// template, one can set limits on the maximum size of a node.
///
/// Normally, nodes default to using the least space they can: the bare minimum they need
/// to display correctly. If their `Node.layout.align` property is set to `fill`, they will
/// instead attempt to use all of the space they're given. Using `SizeLock` allows
/// for a compromise by placing a limit on how much space a node can use.
///
/// Note:
///     Using `layout!"fill"` with `SizeLock` will negate the lock's effect. Use a different
///     alignment like `"start"`, `"center"` or `"end"`.
module fluid.size_lock;

/// Size limit can be used to center content on a wide screen. By using `sizeLock!node`,
/// `.layout!"center"` and `.sizeLimitX`, we can create space around the node for comfortable
/// reading.
@("SizeLock starter example compiles")
unittest {

    import fluid;

    sizeLock!vframe(
        .sizeLimitX(400),       // Maximum width of 800 px
        .layout!(1, "center"),  // Use excess space to center the node
        label(
            "By using sizeLock and setting the right limit, a node can be "
            ~ "forced to use a specific amount of space. This can make your "
            ~ "app easier to use on a wide screen, without affecting smaller "
            ~ "windows or displays."
        ),
    );

}

import std.algorithm;

import fluid.node;
import fluid.utils;
import fluid.style;
import fluid.structs;

@safe:

/// The `sizeLimit` node property sets the maximum amount of space a `SizeLock` node can use.
/// `sizeLimit` can only be used with `SizeLock`.
///
/// Params:
///     x = Maximum width of the node in pixels.
///     y = Maximum height of the node in pixels.
/// Returns:
///     A configured node parameter struct, which can be passed into the `sizeLock` node builder.
///     This will be a `SizeBounds` struct if the input parameters are `float` (preferred),
///     or `SizeLimit` if they are `size_t` like `uint` or `ulong`.
SizeLimit sizeLimit(size_t x, size_t y) {
    return SizeLimit(x, y);
}

/// ditto
SizeLimit sizeLimitX(size_t x) {
    return SizeLimit(x, 0);
}

/// ditto
SizeLimit sizeLimitY(size_t y) {
    return SizeLimit(0, y);
}

/// ditto
FloatSizeLimit sizeLimit(float x, float y) {
    return FloatSizeLimit(
        Vector2(x, y)
    );
}

/// ditto
FloatSizeLimit sizeLimitX(float x) {
    return FloatSizeLimit(
        Vector2(x, float.infinity)
    );
}

/// ditto
FloatSizeLimit sizeLimitY(float y) {
    return FloatSizeLimit(
        Vector2(float.infinity, y)
    );
}

struct SizeLimit {

    size_t x;
    size_t y;

    void apply(T)(SizeLock!T node) {
        node.limit = this;
    }

}

/// This node property defines the maximum size for a `SizeLock` node. Nodes can be given a limit
/// by setting either `width` or `height`.
///
/// The `init` value defaults to no restrictions.
struct FloatSizeLimit {

    import std.math : isFinite;

    /// The imposed limit as a vector. The `x` field is the maximum width,
    /// and `y` is the maximum height. They both default to `infinity`, effectively not
    /// setting any limit.
    auto limit = Vector2(float.infinity, float.infinity);

    /// Returns:
    ///     The maximum width imposed on the node.
    ref inout(float) width() inout return {
        return limit.x;
    }

    /// Returns:
    ///     True if there is a limit applied to node width.
    bool isWidthLimited() const {
        return isFinite(width);
    }

    /// Returns:
    ///     The maximum height imposed on the node.
    ref inout(float) height() inout return {
        return limit.y;
    }

    /// Returns:
    ///     True, if there is a limit applied to node height.
    bool isHeightLimited() const {
        return isFinite(height);
    }

    void apply(T)(SizeLock!T node) {
        node.sizeLimit = this;
    }

}

/// A node builder that constructs a `SizeLock` node. `sizeLock` can be used with other node
/// builders, for example `sizeLock!vframe()` will use a vertical frame as its base,
/// while `sizeLock!hframe()` will use a horizontal frame.
alias sizeLock(alias T) = simpleConstructor!(SizeLock, T);

/// `SizeLock` "locks" the size of a node, limiting the amount of space it will use from the space
/// it is given.
///
/// Size locks are extremely useful for responsible applications, as they can make sure the
/// content doesn't span too much space on large screens. For example, a width limit can be
/// set with `sizeLimitX`, preventing nodes from spanning the entire width of the screen.
class SizeLock(T : Node) : T {

    /// The maximum size of this node.
    /// If a value on either axis is `0`, limit will not be applied on the axis.
    ///
    /// `limit` has been superseded by `sizeLimit`, which uses floats instead of integers, like
    /// the rest of Fluid. For now, it takes priority over `sizeLimit` if set.
    SizeLimit limit;

    /// The maximum size of the node.
    FloatSizeLimit sizeLimit;

    this(T...)(T args) {
        super(args);
    }

    override void resizeImpl(Vector2 space) {

        // Virtually limit the available space
        if (limit.x != 0) space.x = min(space.x, limit.x);
        else space.x = min(space.x, sizeLimit.width);

        if (limit.y != 0) space.y = min(space.y, limit.y);
        else space.y = min(space.y, sizeLimit.height);

        // Resize the child
        super.resizeImpl(space);

        // Apply the limit to the resulting value; fill in remaining space if available
        if (limit.x != 0) minSize.x = max(space.x, min(limit.x, minSize.x));
        else if (sizeLimit.isWidthLimited) {
            minSize.x = max(space.x, min(sizeLimit.width, minSize.x));
        }
        if (limit.y != 0) minSize.y = max(space.y, min(limit.y, minSize.y));
        else if (sizeLimit.isHeightLimited) {
            minSize.y = max(space.y, min(sizeLimit.height, minSize.y));
        }

    }

}

///
unittest {

    import fluid;

    // The frame will appear horizontally-centered in the parent node,
    // and will fill it vertically
    sizeLock!vframe(
        .layout!(1, "center", "fill"),
        .sizeLimitX(400),
        label("Hello, World!")
    );

}
