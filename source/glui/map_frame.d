module glui.map_frame;

import raylib;
import std.algorithm;

import glui.node;
import glui.frame;
import glui.utils;


@safe:


alias mapFrame = simpleConstructor!GluiMapFrame;

class GluiMapFrame : GluiFrame {

    /// Mapping of nodes to their positions.
    Vector2[GluiNode] positions;

    /// If true, the node will prevent its children from leaving the screen space.
    bool preventOverlap;

    static foreach (index; 0..BasicNodeParamLength) {

        /// Construct the frame. Arguments are either nodes, or position vectors affecting all next nodes.
        this(T...)(BasicNodeParam!index params, T children)
        if (!T.length || is(T[0] == Vector2) || is(T[0] : GluiNode)) {

            super(params);

            Vector2 position;

            static foreach (child; children) {

                // Update position
                static if (is(typeof(child) == Vector2)) {

                    position = child;

                }

                // Add child
                else addChild(child, position);

            }

        }

    }

    /// Add a new child to the frame and assign it some position.
    void addChild(GluiNode node, Vector2 position) {

        children ~= node;
        positions[node] = position;
        updateSize();

    }

    void moveChild(GluiNode node, Vector2 position) {

        positions[node] = position;

    }

    protected override void resizeImpl(Vector2 space) {

        minSize = Vector2(0, 0);

        foreach (child; children) {

            // Inherit root
            child.tree = tree;

            // Inherit theme
            if (child.theme is null) {
                child.theme = theme;
            }

            // Ignore hidden children
            if (child.hidden) continue;

            const position = positions[child];

            child.resize(space);

            // Get the children's bottom right corner
            minSize.x = max(minSize.x, position.x + child.minSize.x);
            minSize.y = max(minSize.y, position.y + child.minSize.y);

        }

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        style.drawBackground(outer);

        drawChildren((child) {

            const position = positions.require(child, Vector2(0, 0));

            auto x = inner.x + position.x;
            auto y = inner.y + position.y;

            if (preventOverlap) {

                x = x.clamp(inner.x, inner.x + inner.w - child.minSize.x);
                y = y.clamp(inner.y, inner.y + inner.h - child.minSize.y);

            }

            const childRect = Rectangle(
                x, y,
                child.minSize.x, child.minSize.y
            );

            // Draw the child
            child.draw(childRect);

        });

    }

}
