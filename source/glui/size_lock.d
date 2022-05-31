module glui.size_lock;

import raylib;
import std.algorithm;

import glui.node;
import glui.utils;
import glui.style;



@safe:


/// Create a size-locked node
alias sizeLock(alias T) = simpleConstructor!(GluiSizeLock, T);

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

}

/// Limit the size of a given node (as if imposed by parent) while attempting to copy the behavior of a fill-aligned
/// node.
class GluiSizeLock(T : GluiNode) : T {

    mixin DefineStyles;

    /// The maximum size of this node.
    /// If a value is `0`, it will not be limited.
    SizeLimit limit;

    static foreach (i; 0..BasicNodeParamLength) {

        this(T...)(BasicNodeParam!i params, SizeLimit limit, T args) {

            super(params, args);
            this.limit = limit;

        }

    }

    override void resizeImpl(Vector2 space) {

        // Limit available space
        if (limit.x != 0) space.x = min(space.x, limit.x);
        if (limit.y != 0) space.y = min(space.y, limit.y);

        // Resize
        super.resizeImpl(space);

        // Apply the limit to the resulting value; fill in remaining space if available
        if (limit.x != 0) minSize.x = max(space.x, min(limit.x, minSize.x));
        if (limit.y != 0) minSize.y = max(space.y, min(limit.y, minSize.y));

    }

}
