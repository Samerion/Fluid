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
class FocusChain : NodeChain, FocusIO, WithOrderedFocus, WithPositionalFocus {

    mixin controlIO;

    ActionIOv1 actionIO;
    ActionIOv2 actionIOv2;

    protected {

        /// Focus box tracking action.
        FindFocusBoxAction findFocusBoxAction;

    }

    private {

        Focusable _focus;
        bool _wasInputHandled;
        Appender!(char[]) _buffer;
        PositionalFocusAction _positionalFocusAction;
        OrderedFocusAction _orderedFocusAction;
        Optional!Rectangle _lastFocusBox;

    }

    this() {
        this(null);
    }

    this(Node next) {

        super(next);
        findFocusBoxAction     = new FindFocusBoxAction(this);
        _orderedFocusAction    = new OrderedFocusAction;
        _positionalFocusAction = new PositionalFocusAction;

        // Track the current focus box
        findFocusBoxAction
            .then((Optional!Rectangle rect) => _lastFocusBox = rect);

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

    override protected Optional!Rectangle lastFocusBox() const {
        return _lastFocusBox;
    }

    override protected inout(OrderedFocusAction) orderedFocusAction() inout {
        return _orderedFocusAction;
    }

    override protected inout(PositionalFocusAction) positionalFocusAction() inout {
        return _positionalFocusAction;
    }

    override inout(Focusable) currentFocus() inout {
        return _focus;
    }

    override Focusable currentFocus(Focusable newFocus) {
        return _focus = newFocus;
    }

    override void beforeResize(Vector2) {
        use(actionIO).upgrade(actionIOv2);
        startIO();
    }

    override void afterResize(Vector2) {
        stopIO();
    }

    override void beforeDraw(Rectangle, Rectangle) {

        controlBranchAction(findFocusBoxAction)
            .startAndRelease();

        _wasInputHandled = false;

    }

    override void afterDraw(Rectangle outer, Rectangle inner) {

        controlBranchAction(findFocusBoxAction)
            .stop();

        // Send a frame event to trigger focusImpl
        if (actionIO) {
            emitEvent(ActionIO.frameEvent);
        }
        else if (isFocusActionable) {
            _wasInputHandled = currentFocus.focusImpl();
            _buffer.clear();
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
        if (handled) {
            _wasInputHandled = true;

            // Cancel action events
            emitEvent(ActionIO.noopEvent);
        }

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

        if (actionIOv2) {
            actionIOv2.emitEvent(event, this, 0, &runInputAction);
        }
        else if (actionIO) {
            actionIO.emitEvent(event, 0, &runInputAction);
        }

    }

}
