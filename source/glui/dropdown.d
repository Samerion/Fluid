module glui.dropdown;

import raylib;

import std.traits;
import std.algorithm;

import glui.frame;
import glui.style;
import glui.utils;


@safe:


alias dropdown = simpleConstructor!GluiDropdown;

/// This is an override of GluiFrame to simplify creating dropdowns: if clicked outside of it, it will disappear from
/// the node tree.
class GluiDropdown : GluiFrame {

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
