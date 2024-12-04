///
module actions.ordered_focus_action;

import fluid;

@safe:

@("OrderedFocusAction can select the next focusable node (focusNext)")
unittest {

    auto target = button("", delegate { });
    auto newTarget = button("Next", delegate { });
    auto root = focusSpace(
        button("First", delegate { }),
        button("Previous", delegate { }),
        target,
        label("Obstacle"),
        newTarget,
        button("Last", delegate { }),
    );

    root.draw();
    target.focusNext();
    root.draw();
    assert(root.isFocused(newTarget));
    
}

@("OrderedFocusAction can select the previous focusable node (focusPrevious)")
unittest {

    auto target = button("", delegate { });
    auto newTarget = button("Previous", delegate { });
    auto root = focusSpace(
        button("First", delegate { }),
        newTarget,
        label("Obstacle"),
        target,
        button("Next", delegate { }),
        button("Last", delegate { }),
    );

    root.draw();
    target.focusPrevious();
    root.draw();
    assert(root.isFocused(newTarget));

}

@("OrderedFocusAction can optionally wrap (focusNext)")
unittest {

    auto newTarget = button("First", delegate { });
    auto target = button("Last", delegate { });

    auto root = focusSpace(
        label("Obstacle"),
        newTarget,
        button("Second", delegate { }),
        label("Obstacle"),
        button("Second to last", delegate { }),
        target,
        label("Obstacle"),
    );

    root.draw();
    target.focusNext();
    root.draw();
    assert(root.isFocused(newTarget));

    // Clear focus and disable wrapping
    root.currentFocus = target;
    target.focusNext(false);
    root.draw();
    assert(root.isFocused(target));

}

@("OrderedFocusAction can optionally wrap (focusPrevious)")
unittest {

    auto newTarget = button("Last", delegate { });
    auto target = button("First", delegate { });

    auto root = focusSpace(
        label("Obstacle"),
        target,
        button("Second", delegate { }),
        label("Obstacle"),
        button("Second to last", delegate { }),
        newTarget,
        label("Obstacle"),
    );

    root.draw();
    target.focusPrevious();
    root.draw();
    assert(root.isFocused(newTarget));

    // Clear focus and disable wrapping
    root.currentFocus = target;
    target.focusPrevious(false);
    root.draw();
    assert(root.isFocused(target));

}
