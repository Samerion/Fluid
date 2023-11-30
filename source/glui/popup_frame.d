module glui.popup_frame;

import raylib;

import std.traits;
import std.algorithm;

import glui.frame;
import glui.style;
import glui.utils;


@safe:

deprecated("To be removed in 0.6.0. Use popup() instead")
alias dropdown = popup;

deprecated("To be removed in 0.6.0. Use GluiPopup instead")
alias GluiDropdown = GluiPopup;

deprecated("popup has been renamed to popupFrame")
alias popup = popupFrame;

deprecated("GluiPopup has been renamed to GluiPopupFrame")
alias GluiPopup = GluiPopupFrame;

alias popupFrame = simpleConstructor!GluiPopupFrame;

/// This is an override of GluiFrame to simplify creating popups: if clicked outside of it, it will disappear from
/// the node tree.
class GluiPopupFrame : GluiFrame {

    // TODO: ...unless clicked on another dropdown.

    // Tree actions and recent changes to focusability make it possible to perform a total overhaul of popups. A
    // GluiFocusable popup, when shown, could queue a popup-check action (if not already queued), which would check if
    // focus belongs to *any* popup or its children — and close if not.

    mixin DefineStyles;

    this(T...)(T args) {

        super(args);

    }

    override protected void drawImpl(Rectangle outer, Rectangle inner) @trusted {

        const mousePressed = [EnumMembers!MouseButton].any!IsMouseButtonReleased;

        // Pressed outside!
        if (mousePressed && !isHovered) {

            remove();

        }

        super.drawImpl(outer, inner);

    }

}
