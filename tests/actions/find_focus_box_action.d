module actions.find_focus_box_action;

import fluid;
import optional;

@safe:

alias focusTracker = nodeBuilder!FocusTracker;

/// Runs the focus box action
class FocusTracker : Space {

    FocusIO focusIO;
    FindFocusBoxAction findFocusBoxAction;

    this(Node[] nodes...) {
        super(nodes);
        this.findFocusBoxAction = new FindFocusBoxAction;
    }

    Optional!Rectangle focusBox() const {

        return findFocusBoxAction.focusBox;

    }

    override void resizeImpl(Vector2 space) {

        require(focusIO);
        findFocusBoxAction.focusIO = focusIO;

        super.resizeImpl(space);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        // Start the action before drawing nodes
        auto frame = startBranchAction(findFocusBoxAction);
        super.drawImpl(outer, inner);

    }

}

alias presetFocusBox = nodeBuilder!PresetFocusBox;

/// Always returns the focus box in the same position, regardless of where the node itself
/// is on on the screen
class PresetFocusBox : InputNode!Node {

    Rectangle focusBox;

    this(Rectangle focusBox = Rectangle(10, 10, 10, 10)) {
        this.focusBox = focusBox;
    }

    override void resizeImpl(Vector2 space) {
        super.resizeImpl(space);
        minSize = Vector2();
    }

    override void drawImpl(Rectangle, Rectangle) {

    }

    override Rectangle focusBoxImpl(Rectangle) const {
        return focusBox;
    }

}

@("FindFocusBoxAction will report the current focus box")
unittest {

    PresetFocusBox[2] box;

    auto root = focusChain(
        vspace(
            box[0] = presetFocusBox(Rectangle(2, 2, 2, 2)),
            box[1] = presetFocusBox(Rectangle(4, 4, 6, 6)),
        ),
    );

    // Frame 0: no focus
    root.findFocusBox()
        .then(rect => assert(rect.empty))
        .runWhileDrawing(root);

    // Frame 1: first box has focus
    box[0].focus();
    assert(root.isFocused(box[0]));
    root.findFocusBox()
        .then(rect => assert(rect == box[0].focusBox))
        .runWhileDrawing(root);

    // Frame 2: second box has focus
    box[1].focus();
    assert(root.isFocused(box[1]));
    root.findFocusBox()
        .then(rect => assert(rect == box[1].focusBox))
        .runWhileDrawing(root);

}

@("FindFocusBoxAction can be used as a branch action")
unittest {

    PresetFocusBox[2] box;
    FocusTracker tracker;

    auto root = focusChain(
        tracker = focusTracker(
            box[0] = presetFocusBox(Rectangle(2, 2, 2, 2)),
            box[1] = presetFocusBox(Rectangle(4, 4, 6, 6)),
        )
    );

    root.draw();
    assert(tracker.focusBox.empty);

    box[0].focus();
    root.draw();
    assert(tracker.focusBox == box[0].focusBox);
    assert(tracker.focusBox != box[1].focusBox);

    box[1].focus();
    root.draw();
    assert(tracker.focusBox == box[1].focusBox);
    assert(tracker.focusBox != box[0].focusBox);

}
