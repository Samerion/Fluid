/// Size locking allows placing restrictions on the size of a node. Using the `SizeLock` node
/// template, one can set limits on the maximum size of a node.
///
/// Normally, nodes default to using the least space they can: the bare minimum they need
/// to display correctly. If their `Node.layout.align` property is set to `fill`, they will
/// instead attempt to use all of the space they're given. Using `SizeLock` allows
/// for a compromise by placing a limit on how much space a node can use.
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
import fluid.backend;

@safe:

/// The `sizeLimit` node property sets the maximum amount of space a `SizeLock` node can use.
/// `sizeLimit` can only be used with `SizeLock`.
///
/// Params:
///     x = Maximum width of the node.
///     y = Maximum height of the node.
/// Returns:
///     A configured node parameter struct, which can be passed into the `sizeLock` node builder.
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

struct SizeLimit {

    size_t x;
    size_t y;

    void apply(T)(SizeLock!T node) {
        node.limit = this;
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
    SizeLimit limit;

    this(T...)(T args) {

        super(args);
        this.limit = limit;

    }

    override void resizeImpl(Vector2 space) {

        // Virtually limit the available space
        if (limit.x != 0) space.x = min(space.x, limit.x);
        if (limit.y != 0) space.y = min(space.y, limit.y);

        // Resize the child
        super.resizeImpl(space);

        // Apply the limit to the resulting value; fill in remaining space if available
        if (limit.x != 0) minSize.x = max(space.x, min(limit.x, minSize.x));
        if (limit.y != 0) minSize.y = max(space.y, min(limit.y, minSize.y));

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
