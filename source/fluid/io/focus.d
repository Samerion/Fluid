/// This module contains interfaces for handling focus and connecting focusable nodes with input devices.
module fluid.io.focus;

import optional;
import fluid.node;
import fluid.types;
import fluid.actions;
import fluid.style;

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
interface FocusIO : IO, WithFocus {

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

    /// Write text received from the system. Input devices should call this function every frame to transmit text
    /// that the user wrote on the keyboard, which other nodes can then read through `readText`.
    /// Params:
    ///     text = Text written by the user.
    void typeText(scope const char[] text);

    /// Read text inserted by the user into a buffer.
    ///
    /// Reads a UTF-8 sequence of characters from the system that was typed in by the user during the last frame.
    /// This will be keyboard input as interpreted by the system, using the system's input method, providing support
    /// for internationalization.
    ///
    /// All the text will be written by reference into the provided buffer, overwriting previously stored text.
    /// The returned value will be a slice of this buffer, representing the entire value:
    ///
    /// ---
    /// char[1024] buffer;
    /// int offset;
    /// auto text = focusIO.readText(buffer, offset);
    /// writeln(text);
    /// assert(text is buffer[0 .. text.length] || text is null);
    /// ---
    ///
    /// The buffer may not fit the entire text. Because of this, the function should be called repeatedly until the
    /// returned value is `null`.
    ///
    /// ---
    /// char[1024] buffer;
    /// int offset;
    /// while (true) {
    ///     if (auto text = focusIO.readText(buffer, offset)) {
    ///         writeln(text);
    ///     }
    ///     else {
    ///         break;
    ///     }
    /// }
    /// ---
    ///
    /// This function may not throw: In the instance the offset extends beyond text boundaries, the buffer is empty
    /// or text cannot be read, this function should return `null`, as if no text should remain to read.
    ///
    /// Params:
    ///     buffer = Buffer to write the text to.
    ///     offset = Number of leading bytes to skip when writing into the buffer. Updated to point to the end
    ///         of the buffer. This makes it possible to keep track of position in the text if it doesn't fit
    ///         in a single buffer.
    /// Returns:
    ///     A slice of the given buffer with text that was read. `null` if no text remains to read.
    char[] readText(return scope char[] buffer, ref int offset) nothrow
    out(text; text is buffer[0 .. text.length] || text is null,
        "Returned value must be a slice of the buffer, or be null")
    out(text; text is null || text.length > 0,
        "Returned value must be null if it is empty");

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

        auto focus = focusIO.currentFocus;

        // Only the focused node matters
        if (focus is null || !focus.opEquals(node)) return;

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

/// Base interface for `FocusIO`, providing access and control over the current focusable.
/// Used to create additional interfaces like `WithPositionalFocus` without defining a new I/O
/// set.
interface WithFocus {

    /// Note:
    ///     Currently focused node may have `blocksInput` set to true; take care to check it before calling input
    ///     handling methods.
    /// Returns:
    ///     The currently focused node, or `null` if no node has focus at the moment.
    inout(Focusable) currentFocus() inout nothrow;

    /// Change the currently focused node to another.
    ///
    /// This function may frequently be passed `null` with the intent of clearing the focused node.
    ///
    /// Params:
    ///     newValue = Node to assign focus to.
    /// Returns:
    ///     Node that was focused, to allow chaining assignments.
    Focusable currentFocus(Focusable newValue) nothrow;

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
    ///     Always returns `false` if the parameter is `null`.
    /// Params:
    ///     focusable = Focusable to check.
    final bool isFocused(const Focusable focusable) const nothrow {

        import std.exception : assumeWontThrow;

        auto focus = currentFocus;

        return focus !is null
            && focus.opEquals(cast(const Object) focusable).assumeWontThrow;

    }

    /// Clear current focus (set it to null).
    final void clearFocus() {
        currentFocus = null;
    }

}

/// A ready-made implementation of tabbing for `FocusIO` using `orderedFocusAction`,
/// provided as an interface to subclass from.
///
/// Tabbing can be performed using the `focusNext` and `focusPrevious` methods. They are bound to
/// the corresponding `FluidInputAction` actions and should be automatically picked up by
/// `enableInputActions`. A complete implementation will thus provide the ability to navigate
/// between nodes using the "tab" key.
///
/// To make `WithOrderedFocus` work, it is currently necessary to override two methods:
///
/// ---
/// override protected inout(OrederedFocusAction) orderedFocusAction() inout;
/// override protected void focusPreviousOrNext(FluidInputAction actionType) { }
/// ---
///
/// The latter, `focusPreviousOrNext` must be overridden so that it does nothing if `FocusIO`
/// is in use, as it only applies to the old backend. It will be removed in Fluid 0.8.0.
interface WithOrderedFocus : WithFocus {

    import fluid.node;
    import fluid.style : Style;
    import fluid.actions;
    import fluid.future.action;

    /// Returns:
    ///     An instance of OrderedFocusAction.
    protected inout(OrderedFocusAction) orderedFocusAction() inout;

    /// `focusNext` focuses the next, and `focusPrevious` focuses the previous node, relative
    /// to the one that is currently focused.
    ///
    /// Params:
    ///     isReverse = Reverse direction; if true, focuses the previous node.
    /// Returns:
    ///     Tree action that switches focus to the previous, or next node.
    ///     If no node is currently focused, returns a tree action to focus the first
    ///     or the last node, equivalent to `focusFirst` or `focusLast`.
    ///
    ///     You can use `.then` on the returned action to run a callback the moment
    ///     the focus switches.
    final FocusSearchAction focusNext(bool isReverse = false) {

        auto focus = cast(Node) currentFocus;
        auto self = cast(Node) this;

        if (focus is null) {
            if (isReverse)
                return focusLast();
            else
                return focusFirst();
        }

        // Switch focus
        orderedFocusAction.reset(focus, isReverse);
        self.startAction(orderedFocusAction);

        return orderedFocusAction;

    }

    /// ditto
    final FocusSearchAction focusPrevious() {
        return focusNext(true);
    }

    /// Focus the first (`focusFirst`), or the last node (`focusLast`) that exists inside the
    /// focus space.
    /// Returns:
    ///     Tree action that switches focus to the first, or the last node.
    ///     You can use `.then` on the returned action to run a callback the moment the focus
    ///     switches.
    final FocusSearchAction focusFirst() {
        // TODO cache this, or integrate into OrderedFocusAction?
        return focusRecurseChildren(cast(Node) this);
    }

    /// ditto
    final FocusSearchAction focusLast() {
        auto action = focusRecurseChildren(cast(Node) this);
        action.isReverse = true;
        return action;
    }

    @(FluidInputAction.focusNext)
    final bool focusNext(FluidInputAction) {
        focusNext();
        return true;
    }

    @(FluidInputAction.focusPrevious)
    final bool focusPrevious(FluidInputAction) {
        focusPrevious();
        return true;
    }

}

/// A ready implementation of positional focus for `FocusIO`, enabling switching between nodes
/// using (usually) arrow keys. Used by subclassing in the focus I/O system.
///
/// This interface expects to be provided `positionalFocusAction`, which will be used to locate
/// the target. `lastFocusBox` should be updated with the current focus box every frame; this can
/// be achieved using the `FindFocusBox` branch action.
///
/// This interface exposes a few input actions, which if enabled using `mixin enableInputActions`,
/// will enable navigation using standard Fluid input actions.
///
/// Implementing positional focus using this class requires three overrides in total:
///
/// ---
/// override protected Optional!Rectangle lastFocusBox() const;
/// override protected inout(PositionalFocusAction) positionalFocusAction() inout;
/// override protected void focusInDirection(FluidInputAction actionType) { }
/// ---
///
/// The last overload is necessary to avoid conflicts with the old backend system. It will stop
/// being available in Fluid 0.8.0.
interface WithPositionalFocus : WithFocus {

    import fluid.node;
    import fluid.style : Style;
    import fluid.actions;

    /// To provide a reference for positional focus, the bounding box of the focused node.
    /// Returns:
    ///     Last known focus box of the focused node. May be out of date if the focused node
    ///     has changed since last fetched.
    protected Optional!Rectangle lastFocusBox() const;

    /// Update focus box after it was changed.
    protected Optional!Rectangle lastFocusBox(Optional!Rectangle newFocusBox);

    /// Returns:
    ///     An instance of PositionalFocusAction.
    protected inout(PositionalFocusAction) positionalFocusAction() inout;

    /// Positional focus: Switch focus from the currently focused node to another based on screen
    /// position.
    ///
    /// This launches a tree action that will find a candidate node and switch focus to it during
    /// the next frame. Nodes that are the closest semantically (are in the same container node,
    /// or overall close in the tree) will be chosen first; screen distance will be used when two
    /// nodes have the same weight.
    ///
    /// Returns:
    ///     The launched tree action. You can use `.then` to attach a callback that will run as
    ///     soon as the node is found.
    final FocusSearchAction focusAbove() {
        return focusDirection(Style.Side.top);
    }

    /// ditto
    final FocusSearchAction focusBelow() {
        return focusDirection(Style.Side.bottom);
    }

    /// ditto
    final FocusSearchAction focusToLeft() {
        return focusDirection(Style.Side.left);
    }

    /// ditto
    final FocusSearchAction focusToRight() {
        return focusDirection(Style.Side.right);
    }

    /// ditto
    final FocusSearchAction focusDirection(Style.Side side) {
        return lastFocusBox.match!(
            (Rectangle focusBox) {

                auto reference = cast(Node) currentFocus;

                // No focus, no action to launch
                if (reference is null) return null;

                auto self = cast(Node) this;

                positionalFocusAction.reset(reference, focusBox, side);
                positionalFocusAction.then((Rectangle box) {
                    lastFocusBox = Optional!Rectangle(box);
                });
                self.startAction(positionalFocusAction);

                return positionalFocusAction;

            },
            () => PositionalFocusAction.init,
        );
    }

    @(FluidInputAction.focusUp)
    final bool focusUp() {
        focusAbove();
        return true;
    }

    @(FluidInputAction.focusDown)
    final bool focusDown() {
        focusBelow();
        return true;
    }

    @(FluidInputAction.focusLeft)
    final bool focusLeft() {
        focusToLeft();
        return true;
    }

    @(FluidInputAction.focusRight)
    final bool focusRight() {
        focusToRight();
        return true;
    }

}

/// Focus next or previous focusable node relative to the point of reference.
/// This function only works with nodes compatible with the new I/O system introduced in Fluid 0.7.2.
///
/// Params:
///     node   = Node to use for reference.
///     branch = Branch to search. Nodes that are not children of this node will not be matched.
///         Default to the whole tree.
///     wrap   = If true, if no node remains to focus, focus the first or last node found.
OrderedFocusAction focusNext(Node node, bool wrap = true) {
    auto action = new OrderedFocusAction(node, false, wrap);
    node.startTreeAction(action);
    return action;
}

/// ditto
OrderedFocusAction focusPrevious(Node node, bool wrap = true) {
    auto action = new OrderedFocusAction(node, true, wrap);
    node.startTreeAction(action);
    return action;
}

/// ditto
OrderedFocusAction focusNext(Node node, Node branch, bool wrap = true) {
    auto action = new OrderedFocusAction(node, false, wrap);
    branch.startAction(action);
    return action;
}

/// ditto
OrderedFocusAction focusPrevious(Node node, Node branch, bool wrap = true) {
    auto action = new OrderedFocusAction(node, true, wrap);
    branch.startAction(action);
    return action;
}

final class OrderedFocusAction : FocusSearchAction {

    public {

        /// Node to use as reference. The action will either select the next node that follows, or the previous.
        Node target;

        /// If true, the action finds the previous node. If false, the action finds the next one.
        bool isReverse;

        /// If true, does nothing if the target node is the last (going forward) or the first (going backwards).
        /// Otherwise goes back to the top or bottom respectively.
        bool isWrapDisabled;

    }

    private {

        /// Last focusable node in the branch, first focusable node in the branch. Updates as the node iterates.
        Node _last, _first;

        /// Previous and next focusable relative to the target.
        Node _previous, _next;

    }

    this() {

    }

    this(Node target, bool isReverse = false, bool wrap = true) {
        reset(target, isReverse, wrap);
    }

    /// Re-arm the action.
    void reset(Node target, bool isReverse = false, bool wrap = true) {
        this.target = target;
        this.isReverse = isReverse;
        this.isWrapDisabled = !wrap;
        clearSubscribers();
    }

    override void beforeTree(Node node, Rectangle rect) {

        super.beforeTree(node, rect);
        this._last = null;
        this._first = null;
        this._previous = null;
        this._next = null;

    }

    override void beforeDraw(Node node, Rectangle) {

        // The start node is not a valid subject
        if (startNode && node.opEquals(startNode)) return;

        // Found the target
        if (node.opEquals(target)) {

            // Going backwards: Mark the last focusable as the previous node
            if (isReverse) {
                _previous = _last;
            }

            // Going forwards: Clear the next focusable so it can be overriden by a correct value
            else {
                _next = null;
            }

            return;

        }

        // Ignore nodes that are not focusable
        if (node.castIfAcceptsInput!Focusable is null) return;

        // Set first and next node to this node
        if (_first is null) {
            _first = node;
        }
        if (_next is null) {
            _next = node;
        }

        // Mark as the last found focusable
        _last = node;

    }

    override void afterTree() {

        // Selecting previous or next node
        result = isReverse
            ? _previous
            : _next;

        // No such node, try first/last
        if (!isWrapDisabled && result is null) {
            result = isReverse
                ? _last
                : _first;
        }

        // Found a result!
        if (auto focusable = cast(Focusable) result) {
            focusable.focus();
        }

        stop;

    }

}


/// Find and focus a focusable node based on its visual position; above, below, to the left or to the right
/// of a chosen node.
///
/// Using this function requires knowing the last position of the node, which isn't usually stored. Depending on
/// the usecase, you may need to use `FindFocusBoxAction` earlier.
///
/// Nodes are chosen based on semantical weight — nodes within the same container will be prioritized over
/// nodes in another. Only if the weight is the same, they will be compared based on their visual distance.
///
/// Params:
///     node      = Node to use as reference.
///     focusBox  = Last known `focusBox` of the node.
///     direction = Direction to switch to, if calling `focusDirection`.
/// Returns:
///     A tree action which will run during the next frame. You can attach a callback using its `then` method
///     to process the found node.
PositionalFocusAction focusAbove(Node node, Rectangle focusBox) {
    return focusDirection(node, focusBox, Style.Side.top);
}

/// ditto
PositionalFocusAction focusBelow(Node node, Rectangle focusBox) {
    return focusDirection(node, focusBox, Style.Side.bottom);
}

/// ditto
PositionalFocusAction focusToLeft(Node node, Rectangle focusBox) {
    return focusDirection(node, focusBox, Style.Side.left);
}

/// ditto
PositionalFocusAction focusToRight(Node node, Rectangle focusBox) {
    return focusDirection(node, focusBox, Style.Side.right);
}

/// ditto
PositionalFocusAction focusDirection(Node node, Rectangle focusBox, Style.Side direction) {

    auto action = new PositionalFocusAction(node, focusBox, direction);
    node.startAction(action);
    return action;

}

final class PositionalFocusAction : FocusSearchAction, Publisher!Rectangle {

    public {

        /// Node to use as reference. The action will either select the next node that follows, or the previous.
        Node target;

        /// Focus box of the target node.
        Rectangle focusBox;

        /// Direction of search.
        Style.Side direction;

        /// Focus box of the located node.
        Rectangle resultFocusBox;

        /// Event emitted whenever the action focuses a node, returning its focus box.
        Event!Rectangle onFocusBox;

    }

    private {

        // Properties for the match
        int   resultPriority;   /// Priority assigned to the match.
        float resultDistance2;  /// Distance

        /// Priority assigned to the next node, based on the current tree position.
        int priority;

        /// Multiplier for changes to priority; +1 when moving towards the target, -1 when moving away from it.
        /// This assigns higher priority for nodes that are semantically closer to the match.
        ///
        /// Priority changes only when depth changes; if two nodes are drawn and they're siblings, priority
        /// won't change. Priority will only change if the relation is different, e.g. child, cousin, etc.
        int priorityDirection = 1;

        /// Current depth.
        int depth;

        /// Depth of the last node drawn.
        int lastDepth;

    }

    alias then = typeof(super).then;
    alias then = Publisher!Rectangle.then;

    this() {

    }

    this(Node target, Rectangle focusBox, Style.Side direction) {
        reset(target, focusBox, direction);
    }

    /// Re-arm the action.
    void reset(Node target, Rectangle focusBox, Style.Side direction) {
        this.result = null;
        this.target = target;
        this.focusBox = focusBox;
        this.direction = direction;
        this.resultFocusBox = focusBox;
        clearSubscribers();
    }

    override void clearSubscribers() {
        super.clearSubscribers();
        onFocusBox.clearSubscribers();
    }

    override void subscribe(Subscriber!Rectangle subscriber) {
        onFocusBox ~= subscriber;
    }

    override void beforeTree(Node node, Rectangle rectangle) {
        this.result = null;
        this.priority = 0;
        this.priorityDirection = 1;
        this.depth = 0;
        this.lastDepth = 0;
    }

    override void beforeDraw(Node node, Rectangle) {

        depth++;

    }

    override void afterDraw(Node node, Rectangle, Rectangle, Rectangle inner) {

        import std.math : abs;

        depth--;

        auto focusable = node.castIfAcceptsInput!Focusable;

        // Set priority
        priority += priorityDirection * abs(depth - lastDepth);
        lastDepth = depth;

        // Ignore nodes that don't accept focus
        if (!focusable) return;

        // Found the target, reverse priority direction
        if (node.opEquals(target)) {
            priorityDirection = -1;
            return;
        }

        const box = node.focusBox(inner);
        const dist = distance2(box);


        // Check if this node matches the direction
        if (!box.isBeyond(focusBox, direction)) return;

        // Compare against previous best match
        if (result) {

            // Ignore if the other match has higher priority
            if (resultPriority > priority) return;

            // If priorities are equal, compare distance
            if (resultPriority == priority
                && resultDistance2 < dist) return;

        }

        // Replace the node
        result = node;
        resultPriority  = priority;
        resultDistance2 = dist;
        resultFocusBox  = box;

    }

    override void stopped() {

        if (auto focusable = cast(Focusable) result) {
            focusable.focus();
            onFocusBox(resultFocusBox);
        }

        super.stopped();

    }

    /// Get the square of the distance between given box and the target's `focusBox`.
    private float distance2(Rectangle box) {

        /// Get the center of given rectangle on the axis opposite to the results of getSide.
        float center(Rectangle rect) {

            return direction == Style.Side.left || direction == Style.Side.right
                ? rect.y + rect.height
                : rect.x + rect.width;

        }

        // Distance between box sides facing each other, see `checkDirection`
        const distanceExternal = focusBox.getSide(direction) - box.getSide(direction.reverse);

        /// Distance between centers of the boxes on the other axis
        const distanceOpposite = center(box) - center(focusBox);

        return distanceExternal^^2 + distanceOpposite^^2;

    }

}
