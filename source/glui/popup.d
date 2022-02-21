module glui.popup;

import raylib;

import std.traits;
import std.algorithm;

import glui.frame;
import glui.style;
import glui.utils;


@safe:

deprecated("To be removed in 0.5.0. Use popup() instead")
alias dropdown = popup;

deprecated("To be removed in 0.5.0. Use GluiPopup instead")
alias GluiDropdown = GluiPopup;

alias popup = simpleConstructor!GluiPopup;

/// This is an override of GluiFrame to simplify creating dropdowns: if clicked outside of it, it will disappear from
/// the node tree.
class GluiPopup : GluiFrame {

    // TODO: ...unless clicked on another dropdown.

    mixin DefineStyles;

    this(T...)(T args) {

        super(args);

    }

    override protected void drawImpl(Rectangle outer, Rectangle inner) @trusted {

        const mousePressed = [EnumMembers!MouseButton].any!IsMouseButtonReleased;

        // Pressed outside!
        if (mousePressed && !hovered) {

            remove();

        }

        super.drawImpl(outer, inner);

    }

}
