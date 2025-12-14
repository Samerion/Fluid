///
module fluid.hover_button;

import fluid.node;
import fluid.frame;
import fluid.input;
import fluid.label;
import fluid.style;
import fluid.utils;
import fluid.button;

@safe:
deprecated("`fluid.hover_button` is deprecated, because it is legacy code and has no known usecase. "
    ~ "Please create your own `Button` node subclass and override `mouseImpl`. "
    ~ "`hover_button` will be removed in Fluid 0.9.0."):


alias hoverButton = simpleConstructor!HoverButton;
alias frameHoverButton = simpleConstructor!FrameHoverButton;

alias HoverButton = HoverButtonImpl!Label;
alias FrameHoverButton = HoverButtonImpl!Frame;

/// An button that triggers every frame as long as the button is hovered. Useful for advanced buttons which react to
/// more than just left button click.
///
/// Note, this is a somewhat low-level node and the hover event, as stated, triggers every frame. There are no hover
/// entry nor hover leave events. Make sure you know what you're doing when using this node!
class HoverButtonImpl(T : Node = Label) : ButtonImpl!T {

    mixin enableInputActions;

    /// Create a new hover button.
    /// Params:
    ///     sup = Parameters to pass to the parent node, such as label text.
    this(T...)(T sup) {

        super(sup);

    }

    // Disable action on `press`.
    protected override void press() {

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
