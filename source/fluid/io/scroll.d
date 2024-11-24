/// This module provides basic functionality for scrolling with a mouse wheel.
module fluid.io.scroll;

import fluid.node;
import fluid.types;

@safe:

/// An interface to be implemented by nodes that accept scroll input.
interface FluidScrollable {

    /// Returns true if the node can react to given scroll.
    ///
    /// Should return false if the given scroll has no effect, either because it scroll on an unsupported axis, or
    /// because the axis is currently maxed out.
    bool canScroll(Vector2 value) const;

    /// React to scroll wheel input.
    void scrollImpl(Vector2 value);

    /// Scroll to given child node.
    /// Params:
    ///     child     = Child to scroll to.
    ///     parentBox = Outer box of this node (the scrollable).
    ///     childBox  = Outer box of the child node (the target).
    /// Returns:
    ///     New rectangle for the childBox.
    Rectangle shallowScrollTo(const Node child, Rectangle parentBox, Rectangle childBox);

    /// Get current scroll value.
    float scroll() const;

    /// Set scroll value.
    float scroll(float value);

}
