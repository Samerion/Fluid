///
module fluid.hover_button;

import fluid.node;
import fluid.frame;
import fluid.input;
import fluid.label;
import fluid.style;
import fluid.utils;
import fluid.button;

alias hoverButton = simpleConstructor!(HoverButton!Label);
alias frameHoverButton = simpleConstructor!(HoverButton!Frame);

@safe:

/// An button that triggers every frame as long as the button is hovered. Useful for advanced buttons which react to
/// more than just left button click.
///
/// Note, this is a somewhat low-level node and the hover event, as stated, triggers every frame. There are no hover
/// entry nor hover leave events. Make sure you know what you're doing when using this node!
class HoverButton(T : Node = Label) : Button!T {

    mixin defineStyles;
    mixin enableInputActions;

    /// Create a new hover button.
    /// Params:
    ///     pressed = Action to perform when the button is hovered.
    this(T...)(T sup) {

        super(sup);

    }

    // Disable action on `press`.
    protected override void _pressed() {

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

unittest {

    import fluid.backend;

    int hoverFrameCount;

    auto io = new HeadlessBackend;
    auto root = hoverButton(.nullTheme, "Hello, World!", delegate { hoverFrameCount += 1; });

    root.io = io;

    // Move the mouse away from the button
    io.mousePosition = io.windowSize;
    root.draw();

    assert(hoverFrameCount == 0);

    // Hover the button now
    io.nextFrame;
    io.mousePosition = Vector2(0, 0);
    root.draw();

    assert(hoverFrameCount == 1);

    // Press the button
    io.nextFrame;
    io.press(MouseButton.left);
    root.draw();

    assert(io.isDown(MouseButton.left));
    assert(hoverFrameCount == 2);

    // Wait while the button is pressed
    io.nextFrame;
    root.draw();

    assert(io.isDown(MouseButton.left));
    assert(hoverFrameCount == 3);

    // Release the button
    io.nextFrame;
    io.release(MouseButton.left);
    root.draw();

    assert(io.isUp(MouseButton.left));
    assert(hoverFrameCount == 4);

    // Move the mouse elsewhere
    io.nextFrame;
    io.mousePosition = Vector2(-1, -1);
    root.draw();

    assert(hoverFrameCount == 4);

    // Press the button outside
    io.nextFrame;
    io.press(MouseButton.left);
    root.draw();

    assert(hoverFrameCount == 4);


}
