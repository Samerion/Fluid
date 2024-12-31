///
module fluid.focus_chain;

import optional;
import std.array;

import fluid.node;
import fluid.types;
import fluid.style;
import fluid.utils;
import fluid.actions;
import fluid.node_chain;

import fluid.io.focus;
import fluid.io.action;

import fluid.future.action;

@safe:

alias focusChain = nodeBuilder!FocusChain;

/// A focus chain can be used to separate focus in different areas of the user interface. A device node
/// (focus-based, like a keyboard or gamepad) node can be placed to control nodes inside.
///
/// For hover-based nodes like mouse, see `HoverChain`.
///
/// `FocusChain` only works with nodes compatible with the new I/O system introduced in Fluid 0.7.2.
class FocusChain : NodeChain, FocusIO {

    ActionIO actionIO;

    protected {

        /// Last known focus box, if any.
        Optional!Rectangle lastFocusBox;

        /// Focus box tracking action.
        FindFocusBoxAction findFocusBoxAction;

        /// Action used to switch focus by tabbing between nodes.
        OrderedFocusAction orderedFocusAction;

        /// Action used for directional focus switching, usually with arrow keys.
        PositionalFocusAction positionalFocusAction;

    }

    private {

        Focusable _focus;
        bool _wasInputHandled;
        Appender!(char[]) _buffer;

    }

    this() {
        this(null);
    }

    this(Node next) {

        super(next);
        findFocusBoxAction    = new FindFocusBoxAction(this);
        orderedFocusAction    = new OrderedFocusAction;
        positionalFocusAction = new PositionalFocusAction;

        // Track the current focus box
        findFocusBoxAction
            .then((Optional!Rectangle rect) => lastFocusBox = rect);

    }

    /// If a node inside `FocusChain` triggers an input event (for example a keyboard node,
    /// like a keyboard automaton), another node inside may handle the event. This property
    /// will be set to true after that happens.
    ///
    /// This status is reset the moment this frame is updated again.
    ///
    /// Returns:
    ///     True, if an input action launched during the last frame was passed to a focused node and handled.
    bool wasInputHandled() const {

        return _wasInputHandled;

    }

    override inout(Focusable) currentFocus() inout {
        return _focus;
    }

    override Focusable currentFocus(Focusable newFocus) {
        return _focus = newFocus;
    }

    override void beforeResize(Vector2) {

        use(actionIO);

        auto frame = controlIO!FocusChain();
        frame.start();
        frame.release();

    }

    override void afterResize(Vector2) {

        auto frame = controlIO!FocusChain();
        frame.stop();

    }

    override void beforeDraw(Rectangle, Rectangle) {

        auto frame = controlBranchAction(findFocusBoxAction);
        frame.start();
        frame.release();

        _wasInputHandled = false;

    }

    override void afterDraw(Rectangle outer, Rectangle inner) {

        // If positional focus action is running, it is about to finish;
        // Read the focus box it found
        if (positionalFocusAction.result && !positionalFocusAction.toStop) {
            lastFocusBox = positionalFocusAction.resultFocusBox;
        }

        // Send a frame event to trigger focusImpl
        if (actionIO) {
            actionIO.emitEvent(ActionIO.frameEvent, 0, &runInputAction);
        }
        else if (isFocusActionable) {
            _wasInputHandled = currentFocus.focusImpl();
        }

    }

    /// Handle an input action using the currently focused node.
    ///
    /// Does nothing if no node has focus.
    ///
    /// Params:
    ///     actionID = Input action for the node to handle.
    ///     isActive = If true (default) the action is active, on top of being simply emitted.
    ///         Most handlers only react to active actions.
    /// Returns:
    ///     True if the action was handled.
    ///     Consequently, `wasInputAction` will be set to true.
    bool runInputAction(InputActionID actionID, bool isActive = true) {

        const isFrameAction = actionID == inputActionID!(ActionIO.CoreAction.frame);

        // Try to handle the input action
        const handled =

            // Run the action, and mark input as handled
            (isFocusActionable && currentFocus.actionImpl(this, 0, actionID, isActive))

            // Run local input actions
            || (runLocalInputActions(actionID, isActive))

            // Run focusImpl as a fallback
            || (isFrameAction && isFocusActionable && currentFocus.focusImpl());

        // Mark as handled, if so
        _wasInputHandled = _wasInputHandled || handled;

        // Clear the input buffer after frame action
        if (isFrameAction) {
            _buffer.clear();
        }

        return handled;

    }

    /// ditto
    bool runInputAction(alias action)(bool isActive = true) {

        const id = inputActionID!action;

        return runInputAction(id, isActive);

    }

    /// ditto
    protected final bool runInputAction(InputActionID actionID, bool isActive, int) {

        return runInputAction(actionID, isActive);

    }

    /// Run an input action implemented by this node. These usually perform focus switching
    /// Params:
    ///     actionID = ID of the input action to perform.
    ///     isActive = If true, the action has been activated during this frame.
    /// Returns:
    ///     True if the action was handled, false if not.
    protected bool runLocalInputActions(InputActionID actionID, bool isActive = true) {

        return runInputActionHandler(this, actionID, isActive);

    }

    /// `focusNext` focuses the next, and `focusPrevious` focuses the previous node, relative to the one
    /// that is currently focused.
    ///
    /// Params:
    ///     isReverse = Reverse direction; if true, focuses the previous node.
    /// Returns:
    ///     Tree action that switches focus to the previous, or next node.
    ///     If no node is currently focused, returns a tree action to focus the first or the last node, equivalent
    ///     to `focusFirst` or `focusLast`.
    ///
    ///     You can use `.then` on the returned action to run a callback the moment the focus switches.
    FocusSearchAction focusNext(bool isReverse = false) {

        auto focus = cast(Node) currentFocus;

        if (focus is null) {
            if (isReverse)
                return focusLast();
            else
                return focusFirst();
        }

        // Switch focus
        orderedFocusAction.reset(focus, isReverse);
        startAction(orderedFocusAction);

        return orderedFocusAction;

    }

    /// ditto
    FocusSearchAction focusPrevious() {

        return focusNext(true);

    }

    /// Directional focus: Switch focus from the currently focused node to another based on screen position.
    ///
    /// This launches a tree action that will find a candidate node and switch focus to it during the next frame.
    /// Nodes that are the closest semantically (are in the same container node, or overall close in the tree) will
    /// be chosen first; screen distance will be used when two nodes have the same weight.
    ///
    /// Returns:
    ///     The launched tree action. You can use `.then` to attach a callback that will run as soon as
    ///     the node is found.
    FocusSearchAction focusAbove() {
        return focusDirection(Style.Side.top);
    }

    /// ditto
    FocusSearchAction focusBelow() {
        return focusDirection(Style.Side.bottom);
    }

    /// ditto
    FocusSearchAction focusToLeft() {
        return focusDirection(Style.Side.left);
    }

    /// ditto
    FocusSearchAction focusToRight() {
        return focusDirection(Style.Side.right);
    }

    /// ditto
    FocusSearchAction focusDirection(Style.Side side) {

        return lastFocusBox.match!(
            (Rectangle focusBox) {

                auto reference = cast(Node) currentFocus;

                // No focus, no action to launch
                if (reference is null) return null;

                positionalFocusAction.reset(reference, focusBox, side);
                startAction(positionalFocusAction);

                return positionalFocusAction;

            },
            () => PositionalFocusAction.init,
        );

    }

    /// Focus the first (`focusFirst`), or the last node (`focusLast`) that exists inside the focus space.
    /// Returns:
    ///     Tree action that switches focus to the first, or the last node.
    ///     You can use `.then` on the returned action to run a callback the moment the focus switches.
    FocusSearchAction focusFirst() {
        // TODO cache this, or integrate into OrderedFocusAction?
        return focusRecurseChildren(this);
    }

    /// ditto
    FocusSearchAction focusLast() {
        auto action = focusRecurseChildren(this);
        action.isReverse = true;
        return action;
    }

    @(FluidInputAction.focusNext)
    bool focusNext(FluidInputAction) {
        focusNext();
        return true;
    }

    @(FluidInputAction.focusPrevious)
    bool focusPrevious(FluidInputAction) {
        focusPrevious();
        return true;
    }

    @(FluidInputAction.focusUp)
    bool focusUp() {
        focusAbove();
        return true;
    }

    @(FluidInputAction.focusDown)
    bool focusDown() {
        focusBelow();
        return true;
    }

    @(FluidInputAction.focusLeft)
    bool focusLeft() {
        focusToLeft();
        return true;
    }

    @(FluidInputAction.focusRight)
    bool focusRight() {
        focusToRight();
        return true;
    }

    // Disable default focus switching
    override protected void focusPreviousOrNext(FluidInputAction actionType) { }
    override protected void focusInDirection(FluidInputAction actionType) { }

    /// Type text to read during the next frame.
    ///
    /// This text will then become available for reading through `readText`.
    ///
    /// Params:
    ///     text = Text to write into the buffer.
    override void typeText(scope const char[] text) {
        _buffer ~= text;
    }

    override char[] readText(return scope char[] buffer, ref int offset) nothrow {

        import std.algorithm : min;

        // Read the entire text, nothing remains to be read
        if (offset >= _buffer[].length) return null;

        // Get remaining text
        const text = _buffer[][offset .. $];
        const length = min(text.length, buffer.length);

        offset += length;
        return buffer[0 .. length] = text[0 .. length];

    }

    override void emitEvent(InputEvent event) {

        if (actionIO) {
            actionIO.emitEvent(event, 0, &runInputAction);
        }

    }

}
