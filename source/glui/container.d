module glui.container;

import raylib;

import glui.input;
import glui.style;


@safe:


/// A interface for nodes that contain and control other nodes.
///
/// See_Also: https://git.samerion.com/Samerion/Glui/issues/14
interface GluiContainer {

    /// Find a focusable child node, if any, located closest to the given point.
    GluiFocusable closestFocusable(Vector2 start);
    // TODO

}
