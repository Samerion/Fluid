module glui.border;

import raylib;

import glui.style;


/// Interface for borders
abstract class GluiBorder {

    /// Size of the border.
    SideArray size;

    /// Apply the border, drawing it in the given box.
    abstract void apply(Rectangle borderBox);

}
