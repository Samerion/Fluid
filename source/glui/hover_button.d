///
module glui.hover_button;

import glui.node;
import glui.utils;
import glui.frame;
import glui.label;
import glui.style;
import glui.button;

alias hoverButton = simpleConstructor!(GluiHoverButton!GluiLabel);
alias frameHoverButton = simpleConstructor!(GluiHoverButton!GluiFrame);

@safe:

/// An button that triggers every frame as long as the button is hovered. Useful for advanced buttons which react to
/// more than just left button click.
///
/// Note, this is a somewhat low-level node and the hover event, as stated, triggers every frame. There are no hover
/// entry nor hover leave events. Make sure you know what you're doing when using this node!
class GluiHoverButton(T : GluiNode = GluiLabel) : GluiButton!T {

    mixin DefineStyles;

    /// Create a new hover button.
    /// Params:
    ///     pressed = Action to perform when the button is hovered.
    this(T...)(T sup) {

        super(sup);

    }

    /// Check events
    protected override void mouseImpl() {

        // Simple enough
        submitted();

    }

    protected override bool keyboardImpl() {

        return false;

    }

}

// TODO Needs an example
