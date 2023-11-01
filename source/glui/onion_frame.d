///
module glui.onion_frame;

import raylib;

import glui.frame;
import glui.utils;
import glui.style;

/// Make a new onion frame
alias onionFrame = simpleConstructor!GluiOnionFrame;

@safe:

/// An onion frame places its children as layers, drawing one on top of the other, instead of on the side.
///
/// Children are placed in order of drawing — the last child will be drawn last.
///
/// It might be useful to use OnionFrame as the root node to enable drawing overlaying items, such as modals.
class GluiOnionFrame : GluiFrame {

    mixin DefineStyles;

    this(T...)(T args) {

        super(args);

    }

    protected override void resizeImpl(Vector2 available) {

        import std.algorithm : max;

        minSize = Vector2(0, 0);

        // Check each child
        foreach (child; children) {

            // Resize the child
            child.resize(tree, theme, available);

            // Update minSize
            minSize.x = max(minSize.x, child.minSize.x);
            minSize.y = max(minSize.y, child.minSize.y);

        }

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        style.drawBackground(outer);

        foreach (child; filterChildren) {

            child.draw(inner);

        }

    }

}
