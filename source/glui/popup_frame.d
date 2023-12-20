module glui.popup_frame;

import std.traits;
import std.algorithm;

import glui.frame;
import glui.style;
import glui.utils;
import glui.backend;


@safe:


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

        const mousePressed = tree.io.isReleased(GluiMouseButton.left);

        // Pressed outside!
        if (mousePressed && !isHovered) {

            remove();

        }

        super.drawImpl(outer, inner);

    }

}
