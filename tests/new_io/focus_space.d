module new_io.focus_space;

import fluid;
import fluid.future.pipe;

@safe:

alias focusTracker = nodeBuilder!FocusTracker;

class FocusTracker : Node, Focusable {

    mixin enableInputActions;

    FocusIO focusIO;

    int pressCalls;
    int focusImplCalls;

    override void resizeImpl(Vector2) {
        require(focusIO);
        minSize = Vector2();
    }

    override void drawImpl(Rectangle, Rectangle) {

    }

    override bool blocksInput() const {
        return isDisabled || isDisabledInherited;
    }

    @(FluidInputAction.press)
    void press() {
        assert(!blocksInput);
        pressCalls++;
    }

    bool focusImpl() {
        assert(!blocksInput);
        focusImplCalls++;
        return true;
    }

    void focus() {
        if (!blocksInput) {
            focusIO.currentFocus = this;
        }
    }

    bool isFocused() const {
        return focusIO.isFocused(this);
    }

    alias opEquals = typeof(super).opEquals;

    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

}

@("FocusSpace keeps track of current focus")
unittest {

    int one;
    int two;
    Button incrementOne;
    Button incrementTwo;

    auto root = focusSpace(
        incrementOne = button("One", delegate { one++; }),
        incrementTwo = button("Two", delegate { two++; }),
    );

    root.draw();
    root.currentFocus = incrementOne;
    assert(!root.wasInputHandled);
    assert(one == 0);
    assert(two == 0);
    assert(root.runInputAction!(FluidInputAction.press));
    assert( root.wasInputHandled);
    assert(one == 1);
    assert(two == 0);
    assert(root.runInputAction!(FluidInputAction.press));
    assert(one == 2);
    assert(two == 0);

    root.currentFocus = incrementTwo;
    assert(one == 2);
    assert(two == 0);
    assert(root.runInputAction!(FluidInputAction.press));
    assert(one == 2);
    assert(two == 1);
    assert( root.wasInputHandled);

}

@("Multiple nodes can be focused if they belong to different focus spaces")
unittest {

    FocusSpace focus1, focus2;
    Button button1, button2;
    int one, two;

    auto root = vspace(
        focus1 = focusSpace(
            button1 = button("One", delegate { one++; }),
        ),
        focus2 = focusSpace(
            button2 = button("Two", delegate { two++; }),
        ),
    );

    root.draw();
    button1.focus();
    button2.focus();
    assert(button1.isFocused);
    assert(button2.isFocused);
    assert(cast(Node) focus1.currentFocus == button1);
    assert(cast(Node) focus2.currentFocus == button2);

    focus1.runInputAction!(FluidInputAction.press);
    assert(one == 1);
    assert(two == 0);
    focus2.runInputAction!(FluidInputAction.press);
    assert(one == 1);
    assert(two == 1);

}

@("FocusSpace can be nested")
unittest {

    FocusSpace focus1, focus2;
    Button button1, button2;
    int one, two;

    auto root = vspace(
        focus1 = focusSpace(
            button1 = button("One", delegate { one++; }),
            focus2 = focusSpace(
                button2 = button("Two", delegate { two++; }),
            ),
        ),
    );

    root.draw();
    button1.focus();
    button2.focus();

    assert(cast(Node) focus1.currentFocus == button1);
    assert(cast(Node) focus2.currentFocus == button2);

}

@("FocusSpace supports tabbing")
unittest {

    Button[3] buttons;

    auto root = focusSpace(
        buttons[0] = button("One", delegate { }),
        buttons[1] = button("Two", delegate { }),
        buttons[2] = button("Three", delegate { }),
    );
    root.draw();
    buttons[0].focus();
    assert(root.isFocused(buttons[0]));

    root.runInputAction!(FluidInputAction.focusNext);
    root.draw();
    assert(root.isFocused(buttons[1]));

    root.runInputAction!(FluidInputAction.focusNext);
    root.draw();
    assert(root.isFocused(buttons[2]));

    root.runInputAction!(FluidInputAction.focusNext);
    root.draw();
    assert(root.isFocused(buttons[0]));

}
@("FocusSpace supports tabbing (chained)")
unittest {

    Button[3] buttons;

    auto root = focusSpace(
        buttons[0] = button("One", delegate { }),
        buttons[1] = button("Two", delegate { }),
        buttons[2] = button("Three", delegate { }),
    );
    root.draw();
    buttons[0].focus();
    assert(root.isFocused(buttons[0]));

    const frames = root.focusNext
        .then((Node a) => assert(a == buttons[1]))
        .then(()       => root.focusNext)
        .then((Node a) => assert(a == buttons[2]))
        .then(()       => root.focusNext)
        .then((Node a) => assert(a == buttons[0]))
        .runWhileDrawing(root, 5);

    assert(frames == 3);

}

@("FocusSpace automatically focuses first item on tab")
unittest {

    Button[3] buttons;
    auto root = focusSpace(
        buttons[0] = button("One", delegate { }),
        buttons[1] = button("Two", delegate { }),
        buttons[2] = button("Three", delegate { }),
    );

    assert(root.currentFocus is null);

    // Via chains
    root.focusNext()
        .then((Node n) => assert(n == buttons[0]))
        .then(()       => assert(root.isFocused(buttons[0])))
        .runWhileDrawing(root, 1);

    // Via input actions
    root.clearFocus();
    assert(!root.isFocused(buttons[0]));
    root.runInputAction!(FluidInputAction.focusNext);
    root.draw();
    assert(root.isFocused(buttons[0]));

}

@("FocusSpace focuses the last item on shift tab")
unittest {

    Button[3] buttons;
    auto root = focusSpace(
        buttons[0] = button("One", delegate { }),
        buttons[1] = button("Two", delegate { }),
        buttons[2] = button("Three", delegate { }),
    );

    assert(root.currentFocus is null);

    // Via chains
    root.focusPrevious()
        .then((Node n) => assert(n == buttons[2]))
        .then(()       => assert(root.isFocused(buttons[2])))
        .runWhileDrawing(root, 1);

    // Via input actions
    root.clearFocus();
    assert(!root.isFocused(buttons[2]));
    root.runInputAction!(FluidInputAction.focusPrevious);
    root.draw();
    assert(root.isFocused(buttons[2]));

}

@("FocusSpace tabbing wraps")
unittest {

    Button[3] buttons;
    auto root = focusSpace(
        buttons[0] = button("One", delegate { }),
        vspace(
            buttons[1] = button("Two", delegate { }),
        ),
        buttons[2] = button("Three", delegate { }),
    );

    root.focusNext()
        .then(node => assert(node == buttons[0]))
        .then(()   => root.focusNext())
        .then(node => assert(node == buttons[1]))
        .then(()   => root.focusNext())
        .then(node => assert(node == buttons[2]))
        .then(()   => root.focusNext())
        .then(node => assert(node == buttons[0]))
        .runWhileDrawing(root, 4);

    root.clearFocus();
    root.focusPrevious()
        .then(node => assert(node == buttons[2]))
        .then(()   => root.focusPrevious())
        .then(node => assert(node == buttons[1]))
        .then(()   => root.focusPrevious())
        .then(node => assert(node == buttons[0]))
        .then(()   => root.focusPrevious())
        .then(node => assert(node == buttons[2]))
        .runWhileDrawing(root, 4);

}

@("FocusSpace supports directional movement")
unittest {

    Button[5] buttons;
    auto root = focusSpace(
        buttons[0] = button("Zero", delegate { }),
        hspace(
            buttons[1] = button("One", delegate { }),
            buttons[2] = button("Two", delegate { }),
            buttons[3] = button("Three", delegate { }),
        ),
        buttons[4] = button("Four", delegate { }),
    );

    root.currentFocus = buttons[0];
    root.draw();

    // Vertical focus
    root.focusBelow().thenAssertEquals(buttons[1])
        .then(() => root.focusBelow).thenAssertEquals(buttons[4])
        .then(() => root.focusAbove).thenAssertEquals(buttons[1])

        // Horizontal
        .then(() => root.focusToRight)
        .thenAssertEquals(buttons[2])
        .then(() => root.focusToRight)
        .thenAssertEquals(buttons[3])
        .then(() => root.focusToRight)
        .thenAssertEquals(null)
        .then(() => assert(root.isFocused(buttons[3])))

        // Vertical, again
        .then(() => root.focusAbove)
        .thenAssertEquals(buttons[0])
        .runWhileDrawing(root, 8);

}

@("FocusSpace calls focusImpl as a fallback")
unittest {

    auto map = InputMapping();
    map.bindNew!(FluidInputAction.press)(KeyboardIO.codes.space);

    auto tracker = focusTracker();
    auto focus = focusSpace(tracker);
    auto root = inputMapSpace(map, focus);

    root.draw();
    assert(tracker.focusImplCalls == 0);

    focus.currentFocus = tracker;
    root.draw();

    assert(tracker.pressCalls == 0);
    assert(tracker.focusImplCalls == 1);

    focus.emitEvent(KeyboardIO.press.space);
    root.draw();

    assert(tracker.pressCalls == 1);
    assert(tracker.focusImplCalls == 1);

    focus.emitEvent(KeyboardIO.hold.space);
    root.draw();

    assert(tracker.pressCalls == 1);
    assert(tracker.focusImplCalls == 2);

    // Unrelated input actions cannot trigger fallback
    focus.runInputAction!(FluidInputAction.press);
    assert(tracker.pressCalls == 2);
    focus.runInputAction!(FluidInputAction.contextMenu);
    assert(tracker.pressCalls == 2);
    assert(tracker.focusImplCalls == 2);

}

@("FocusSpace calls focusImpl if there is no ActionIO")
unittest {

    auto tracker = focusTracker();
    auto focus = focusSpace(tracker);
    auto root = focus;

    root.draw();
    assert(tracker.focusImplCalls == 0);

    focus.currentFocus = tracker;
    root.draw();

    assert(tracker.focusImplCalls == 1);

}

@("FocusSpace doesn't trigger events on disabled nodes")
unittest {

    auto tracker = focusTracker();
    auto focus = focusSpace(tracker);
    auto root = focus;

    // Focused for a frame while enabled
    focus.currentFocus = tracker;
    root.draw();
    assert(tracker.focusImplCalls == 1);

    // Disabled while focused
    tracker.disable();
    root.draw();
    assert(tracker.focusImplCalls == 1);
    assert(tracker.pressCalls == 0);

    root.runInputAction!(FluidInputAction.press);
    root.draw();
    assert(tracker.pressCalls == 0);


}

@("Tabbing skips over disabled nodes")
unittest {

    Button btn1, btn2, btn3;

    auto root = focusSpace(
        btn1 = button("One", delegate { }),
        btn2 = button(.disabled, "Two", delegate { }),
        btn3 = button("Three", delegate { }),
    );

    root.currentFocus = btn1;
    root.draw();
    root.focusNext()
        .thenAssertEquals(btn3)
        .then(() => root.focusNext)
        .thenAssertEquals(btn1)
        .then(() => root.focusPrevious)
        .thenAssertEquals(btn3)
        .then(() => root.focusPrevious)
        .thenAssertEquals(btn1)
        .runWhileDrawing(root);

}
