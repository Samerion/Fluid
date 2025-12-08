/// [OnionFrame] draws its children one on another, in layers. It is used to draw one node in
/// front of another.
///
/// Use [onionFrame] to build.
module fluid.onion_frame;

import fluid.frame;
import fluid.utils;
import fluid.style;
import fluid.structs;

@safe:

/// [nodeBuilder] for [OnionFrame]. `OnionFrame` accepts any amount of child nodes, ordered from
/// bottom (first) to top (last).
alias onionFrame = nodeBuilder!OnionFrame;

///
@("onionFrame builder example")
unittest {
    import fluid.label;
    onionFrame(
        label("Drawn at the bottom, behind other nodes"),
        label("Drawn in the middle, in between other nodes"),
        label("Drawn at the top, in front of other nodes"),
    );
}

/// This [Frame] draws nodes in a stack, in the same assigned space. It layers them, so each node
/// appears in front of the last.
class OnionFrame : Frame {

    this(T...)(T args) {
        super(args);
    }

    protected override void resizeImpl(Vector2 available) {
        import std.algorithm : max;

        use(canvasIO);
        minSize = Vector2(0, 0);

        // Check each child
        foreach (child; children) {
            resizeChild(child, available);
            minSize.x = max(minSize.x, child.minSize.x);
            minSize.y = max(minSize.y, child.minSize.y);
        }
    }

    protected override void drawChildren(Rectangle inner) {
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
        imageView(
            .layout!"fill",
            "logo.png"
        ),

        // Draw a label on top of the image, in the middle
        label(
            .layout!"center",
            "Hello, Fluid!"
        ),

    );
}
