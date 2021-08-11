///
module glui.structs;

import raylib;
import std.conv;
import glui.node;

@safe:

/// Create a new layout
/// Params:
///     expand = Numerator of the fraction of space this node should occupy in the parent.
///     align_ = Align of the node (horizontal and vertical).
///     alignX = Horizontal align of the node.
///     alignY = Vertical align of the node.
Layout layout(uint expand, NodeAlign alignX, NodeAlign alignY) {

    return Layout(expand, [alignX, alignY]);

}

/// Ditto
Layout layout(uint expand, NodeAlign align_) {

    return Layout(expand, align_);

}

/// Ditto
Layout layout(NodeAlign alignX, NodeAlign alignY) {

    return Layout(0, [alignX, alignY]);

}

/// Ditto
Layout layout(NodeAlign align_) {

    return Layout(0, align_);

}

/// Ditto
Layout layout(uint expand) {

    return Layout(expand);

}

/// CTFE version of the layout constructor, allows using strings instead of enum members, to avoid boilerplate.
Layout layout(uint expand, string alignX, string alignY)() {

    return Layout(expand, [alignX.to!NodeAlign, alignY.to!NodeAlign]);

}

/// Ditto
Layout layout(uint expand, string align_)() {

    return Layout(expand, align_.to!NodeAlign);

}

/// Ditto
Layout layout(string alignX, string alignY)() {

    return Layout(0, [alignX.to!NodeAlign, alignY.to!NodeAlign]);

}

/// Ditto
Layout layout(string align_)() {

    return Layout(0, align_.to!NodeAlign);

}

/// Ditto
Layout layout(uint expand)() {

    return Layout(expand);

}

/// Represents a node's layout
struct Layout {

    /// Fraction of available space this node should occupy in the node direction.
    ///
    /// If set to `0`, the node doesn't have a strict size limit and has size based on content.
    uint expand;

    /// Align the content box to a side of the occupied space.
    NodeAlign[2] nodeAlign;

}

enum NodeAlign {

    start, center, end, fill

}

package interface GluiFocusable {

    void focus();
    bool isFocused() const;
    void mouseImpl();
    bool keyboardImpl();

}

/// Global data for the layout tree.
struct LayoutTree {

    /// Root node of the tree.
    GluiNode root;

    /// Top-most hovered node in the tree.
    GluiNode hover;

    /// Currently focused node.
    GluiFocusable focus;

    /// Check if keyboard input was handled after rendering is has completed.
    bool keyboardHandled;

    /// Scissors stack.
    package Rectangle[] scissors;

    debug (Glui_DisableScissors) {

        void pushScissors(Rectangle) { }
        void popScissors() { }

    }

    else {

        /// Start scissors mode.
        void pushScissors(Rectangle rect) {

            import std.algorithm : min, max;

            auto result = rect;

            // There's already something on the stack
            if (scissors.length) {

                const b = scissors[$-1];

                // Intersect
                result.x = max(rect.x, b.x);
                result.y = max(rect.y, b.y);
                result.w = min(rect.x + rect.w, b.x + b.w) - result.x;
                result.h = min(rect.y + rect.h, b.y + b.h) - result.y;

            }

            // Push to the stack
            scissors ~= result;

            // Start the mode
            applyScissors(result);

        }

        void popScissors() @trusted {

            // Pop the stack
            scissors = scissors[0 .. $-1];

            // There's still something left
            if (scissors.length) {

                // Start again
                applyScissors(scissors[$-1]);

            }

            // Nope, end
            else EndScissorMode();

        }

        private void applyScissors(Rectangle rect) @trusted {

            BeginScissorMode(rect.x.to!int, rect.y.to!int, rect.w.to!int, rect.h.to!int);

        }

    }

}
