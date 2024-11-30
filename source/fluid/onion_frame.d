///
module fluid.onion_frame;

import fluid.frame;
import fluid.utils;
import fluid.style;
import fluid.backend;


@safe:


/// An onion frame places its children as layers, drawing one on top of the other, instead of on the side.
///
/// Children are placed in order of drawing — the last child will be drawn last, and so, will appear on top.
alias onionFrame = simpleConstructor!OnionFrame;

/// ditto
class OnionFrame : Frame {

    this(T...)(T args) {

        super(args);

    }

    protected override void resizeImpl(Vector2 available) {

        import std.algorithm : max;

        minSize = Vector2(0, 0);

        // Check each child
        foreach (child; children) {

            // Resize the child
            resizeChild(child, available);

            // Update minSize
            minSize.x = max(minSize.x, child.minSize.x);
            minSize.y = max(minSize.y, child.minSize.y);

        }

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        style.drawBackground(tree.io, outer);

        foreach (child; filterChildren) {

            drawChild(child, inner);

        }

    }

}

///
unittest {

    import fluid;

    auto myFrame = onionFrame(

        // Draw an image
        imageView("logo.png"),

        // Draw a label in the middle of the frame
        label(
            layout!(1, "center"),
            "Hello, Fluid!"
        ),

    );

}
