/// A button can be clicked by the user to trigger an event.
module fluid.button;

@safe:

/// [Button] is described with text. It can be constructed with the [button][button] node builder.
@("Button reference example")
unittest {
    run(
        button("Click me!", delegate { }),
    );
}

/// Text is not enough? A [FrameButton] can mix content — for example, place an
/// [ImageView][fluid.image_view] inside if you need an icon. Add text with [Label].
///
/// A FrameButton can be created with [vframeButton], to align content vertically — or with
/// [hframeButton], for horizontal content.
@("FrameButton reference example")
unittest {
    import fluid.image_view;
    run(
        hframeButton(
            HitFilter.hitBranch,
            imageView("myicon.png"),
            label("Click me!"),
            delegate { }
        ),
    );
}

import fluid.node;
import fluid.frame;
import fluid.input;
import fluid.label;
import fluid.utils;
import fluid.style;
import fluid.structs;

/// A [node builder][nodeBuilder] to create a [Button] labelled with text.
/// It takes a string for the label text, and a delegate describing the effect.
alias button = nodeBuilder!Button;

/// A [node builder][nodeBuilder] to create a [FrameButton]. The contents will be aligned
/// horizontally (for `hframeButton`) or vertically (for `vframeButton`). Pass a delegate to
/// describe the button's effects as the last argument.
alias hframeButton = nodeBuilder!(FrameButton, (a) {
    a.isHorizontal = true;
});

/// ditto
alias vframeButton = nodeBuilder!FrameButton;

/// A [ButtonImpl] based on a [Label]. It will display text.
///
/// Note:
///     In a future update, `Button` will be a dedicated subclass of `ButtonImpl!Node`.
///     See [issue #298](https://git.samerion.com/Samerion/Fluid/issues/298).
alias Button = ButtonImpl!Label;

/// A [ButtonImpl] based on a [Frame].
alias FrameButton = ButtonImpl!Frame;

/// A button can be pressed by the user to trigger an action.
///
/// `ButtonImpl` is a template, and can be used with most other nodes.
class ButtonImpl(T : Node = Label) : InputNode!T {

    mixin enableInputActions;

    /// A callback to run when the button is pressed. This is actually an alias for
    /// [InputNode.submitted][fluid.input.InputNode].
    alias pressed = submitted;

    // Button status
    public {

        /// Set to true while the button is held down; can be used for styling.
        bool isPressed;

    }

    /// Create a new button.
    /// Params:
    ///     sup     = Parameters to pass to the parent node.
    ///         Most commonly, this defines the button's visual content.
    ///         For [Button] this will be the label text.
    ///     pressed = Action to perform when the button is pressed.
    this(T...)(T sup, void delegate() @safe pressed) {
        super(sup);
        this.pressed = pressed;
    }

    /// Handle input by calling the [pressed][Button.pressed] delegate assigned to this
    /// button.
    ///
    /// This method is bound to the [press input action][FluidInputAction.press].
    @(FluidInputAction.press)
    void press() @trusted {
        if (pressed) pressed();
    }

    static if (is(typeof(text) : string))
    override string toString() const {

        import std.format;
        return format!"button(%s)"(text);

    }

}
