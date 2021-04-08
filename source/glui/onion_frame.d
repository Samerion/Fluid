///
module glui.onion_frame;

import raylib;

import glui.frame;
import glui.utils;

/// Make a new onion frame
alias onionFrame = simpleConstructor!GluiOnionFrame;

/// An onion frame places its children as layers, drawing one on top of the other, instead of on the side.
///
/// Children are placed in order of drawing — the last child will be drawn last.
///
/// It might be useful to use OnionFrame as the root node to enable drawing overlaying items, such as modals.
class GluiOnionFrame : GluiFrame {

    this(T...)(T args) {

        super(args);

    }

    protected override void resizeImpl(Vector2 available) {

        import std.algorithm : max;

        minSize = Vector2(0, 0);

        // Check each child
        foreach (child; children) {

            // Inherit root
            child.tree = tree;

            // Inherit theme
            if (child.theme is null) {

                child.theme = theme;

            }

            // Resize the child
            child.resize(available);

            // Update minSize
            minSize.x = max(minSize.x, child.minSize.x);
            minSize.y = max(minSize.y, child.minSize.y);

        }

    }

    protected override void drawImpl(Rectangle area) {

        const style = pickStyle();
        style.drawBackground(area);

        foreach (child; children) {

            child.draw(area);

        }

    }

}
