/// This module implements interfaces for handling focus and connecting focusable nodes with input devices.
module fluid.io.focus;

import optional;
import fluid.types;

import fluid.future.pipe;
import fluid.future.context;
import fluid.future.branch_action;

import fluid.io.action;

public import fluid.io.action : InputEvent, InputEventCode;

@safe:

/// `FocusIO` is an input handler system that reads events off devices like keyboards or gamepads, which do not
/// map directly to screen coordinates.
///
/// Most of the time, `FocusIO` systems will pass the events they receive to an `ActionIO` system, and then send
/// these actions to a focused node.
///
/// Multiple different `FocusIO` instances can coexist in the same tree, allowing for multiple different nodes
/// to be focused at the same time, as long as they belong in different branches of the node tree. That means
/// two different nodes can be focused by two different `FocusIO` systems, but a single `FocusIO` system can only
/// focus a single node.
interface FocusIO : IO {

    /// Read an input event from an input device. Input devices will call this function every frame 
    /// if an input event occurs.
    ///
    /// `FocusIO` will usually pass these down to an `ActionIO` system. It is up to `FocusIO` to decide how 
    /// the input and the resulting input actions are handled, though they will most often be passed 
    /// to the focused node.
    ///
    /// Params:
    ///     event = Input event the system should save.
    void emitEvent(InputEvent event);

    /// Note:
    ///     Currently focused node may have `blocksInput` set to true; take care to check it before calling input
    ///     handling methods.
    /// Returns:
    ///     The currently focused node, or `null` if no node has focus at the moment.
    inout(Focusable) currentFocus() inout;

    /// Change the currently focused node to another.
    ///
    /// This function may frequently be passed `null` with the intent of clearing the focused node.
    ///
    /// Params:
    ///     newValue = Node to assign focus to.
    /// Returns:
    ///     Node that was focused, to allow chaining assignments.
    Focusable currentFocus(Focusable newValue);

    /// Returns:
    ///     True, if a node focused (`currentFocus` is not null) and if it accepts input (`currentFocus.blocksInput`
    ///     is false).
    final bool isFocusActionable() const {

        auto focus = currentFocus;

        return focus !is null
            && !focus.blocksInput;

    }

    /// Returns:
    ///     True if the focusable is currently focused.
    /// Params:
    ///     focusable = Focusable to check.
    final bool isFocused(const Focusable focusable) const {

        return currentFocus.opEquals(cast(const Object) focusable);

    }

    /// Clear current focus (set it to null).
    final void clearFocus() {
        currentFocus = null;
    }

}

/// Nodes implementing this interface can be focused by a `FocusIO` system.
interface Focusable : Actionable {

    /// Handle input. Called each frame when focused.
    ///
    /// This method should not be called if `blocksInput` is true.
    /// 
    /// Returns:
    ///     True if focus input was handled, false if it was ignored.
    bool focusImpl()
    in (!blocksInput, "This node currently doesn't accept input.");

    /// Set focus to this node.
    ///
    /// Implementation would usually check `blocksInput` and call `focusIO.focus` on self for this to take effect. 
    /// A node may override this method to redirect the focus to another node (by calling its `focus()` method), 
    /// or ignore the request.
    ///
    /// Focus should do nothing if the node `isDisabled` is true or if
    void focus();

    /// Returns: 
    ///     True if this node has focus. Recommended implementation: `return this == focusIO.focus`. 
    ///     Proxy nodes, such as `FieldSlot` might choose to return the value of the node they hold.
    bool isFocused() const;

}

/// Find the focus box using a `FindFocusAction`.
/// Params:
///     focusIO = FocusIO node owning the focus.
FindFocusBoxAction findFocusBox(FocusIO focusIO) {

    import fluid.node;

    auto node = cast(Node) focusIO;
    assert(node, "Given FocusIO is not a node");
    
    auto action = new FindFocusBoxAction(focusIO);
    node.startAction(action);
    return action;

}

/// This branch action tracks and reports position of the current focus box.
class FindFocusBoxAction : BranchAction, Publisher!(Optional!Rectangle) {

    import fluid.node;

    public {

        /// System holding the focused node in question.
        FocusIO focusIO;

        /// Focus box reported by the node, if any. Use `.then((Rectangle) { ... })` to get the focus box the moment
        /// it is found.
        Optional!Rectangle focusBox;

    }

    private {

        Subscriber!(Optional!Rectangle) _onFinishRectangle;

    }

    /// Prepare the action. To work, it needs to know the `FocusIO` it will search in.
    /// At this point it can be omitted, but it has to be set before the action launches.
    this(FocusIO focusIO = null) {

        this.focusIO = focusIO;

    }

    alias then = typeof(super).then;
    alias then = Publisher!(Optional!Rectangle).then;

    alias subscribe = typeof(super).subscribe;

    override void subscribe(Subscriber!(Optional!Rectangle) subscriber) {

        assert(_onFinishRectangle is null, "Subscriber already connected.");
        _onFinishRectangle = subscriber;

    }

    override void started() {

        assert(focusIO !is null, "FindFocusBoxAction launched without assigning focusIO");

        this.focusBox = Optional!Rectangle();

    }

    override void beforeDraw(Node node, Rectangle, Rectangle, Rectangle inner) {

        // Only the focused node matters
        if (cast(Node) focusIO.currentFocus != node) return;

        this.focusBox = node.focusBox(inner);
        stop;

    }

    override void stopped() {

        super.stopped();

        if (_onFinishRectangle) {
            _onFinishRectangle(focusBox);
        }

    }
    
}

/// Using FindFocusBoxAction.
@("FindFocusBoxAction setup example")
unittest {

    import fluid.node;
    import fluid.space;

    class MyNode : Space {

        FocusIO focusIO;
        FindFocusBoxAction findFocusBoxAction;

        this(Node[] nodes...) {
            super(nodes);
            this.findFocusBoxAction = new FindFocusBoxAction;
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

            // Inspect the result
            auto result = findFocusBoxAction.focusBox;

        }

    }

}
