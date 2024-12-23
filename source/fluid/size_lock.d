module fluid.size_lock;

import std.algorithm;

import fluid.node;
import fluid.utils;
import fluid.style;
import fluid.backend;


@safe:


SizeLimit sizeLimit(size_t x, size_t y) {

    return SizeLimit(x, y);

}

SizeLimit sizeLimitX(size_t x) {

    return SizeLimit(x, 0);

}

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

/// `sizeLock` "locks" a node, restricting space avilable to it, and making it fill the space, if possible.
///
/// Size-locks are extremely useful for responsible applications, making sure the content doesn't span too much space on
/// large screens, for example on wide-screen, where the content can be applied a sizeLimitX, so it never spreads to
/// more than the set value.
alias sizeLock(alias T) = simpleConstructor!(SizeLock, T);

/// ditto
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

    // The frame will appear horizontally-centered in the parent node, while filling it vertically
    sizeLock!vframe(
        layout!(1, "center", "fill"),
        sizeLimitX(400),

        label("Hello, World!")
    );

}
