module glui.container;

import raylib;

import glui.input;
import glui.style;


@safe:


/// A interface for nodes that contain and control other nodes.
///
/// See_Also: https://git.samerion.com/Samerion/Glui/issues/14
interface GluiContainer {

    /// Find a focusable child node, if any, located closest to the given point, but distinct from the given node.
    /// Params:
    ///     start = Position to start search from.
    ///     other = Node to avoid.
    GluiFocusable closestFocusable(Vector2 start, GluiFocusable other = null)
    out (r; r is null || r !is other, "Returned focusable must not be `other`");
    // TODO

}
