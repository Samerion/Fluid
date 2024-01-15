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

}

/// `sizeLock` "locks" a node, restricting space avilable to it, and making it fill the space, if possible.
///
/// Size-locks are extremely useful for responsible applications, making sure the content doesn't span too much space on
/// large screens, for example on wide-screen, where the content can be applied a sizeLimitX, so it never spreads to
/// more than the set value.
alias sizeLock(alias T) = simpleConstructor!(FluidSizeLock, T);

/// ditto
class FluidSizeLock(T : FluidNode) : T {

    mixin DefineStyles;

    /// The maximum size of this node.
    /// If a value on either axis is `0`, limit will not be applied on the axis.
    SizeLimit limit;

    this(T...)(NodeParams params, SizeLimit limit, T args) {

        super(params, args);
        this.limit = limit;

    }

    deprecated("BasicNodeParams have been replaced with NodeParams; please use this(NodeParams, SizeLimit, T)") {

        static foreach (i; 0..BasicNodeParamLength) {

            this(T...)(BasicNodeParam!i params, SizeLimit limit, T args) {

                super(params, args);
                this.limit = limit;

            }

        }

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

unittest {

    import fluid.space;
    import fluid.label;
    import fluid.frame;
    import fluid.structs;

    auto io = new HeadlessBackend;
    auto root = sizeLock!vframe(
        layout!("center", "fill"),
        sizeLimitX(400),
        label("Hello, World!"),
    );

    root.io = io;
    root.theme = nullTheme.makeTheme!q{
        FluidFrame.styleAdd.backgroundColor = color!"1c1c1c";
        FluidLabel.styleAdd.textColor = color!"eee";
    };

    {
        root.draw();

        // The rectangle should display neatly in the middle of the display, limited to 400px
        io.assertRectangle(Rectangle(200, 0, 400, 600), color!"1c1c1c");
    }

    {
        io.nextFrame;
        root.layout = layout!("start", "fill");
        root.updateSize();
        root.draw();

        io.assertRectangle(Rectangle(0, 0, 400, 600), color!"1c1c1c");
    }

    {
        io.nextFrame;
        root.layout = layout!"center";
        root.limit = sizeLimit(200, 200);
        root.updateSize();
        root.draw();

        io.assertRectangle(Rectangle(300, 200, 200, 200), color!"1c1c1c");
    }

}
