/// 
module fluid.focus_space;

import optional;

import fluid.node;
import fluid.space;
import fluid.types;
import fluid.style;
import fluid.utils;
import fluid.actions;

import fluid.io.focus;
import fluid.io.action;

import fluid.future.action;

@safe:

alias focusSpace = nodeBuilder!FocusSpace;

/// A focus space can be used to separate focus in different areas of the user interface. A device node
/// (focus-based, like a keyboard or gamepad) node can be placed to control nodes inside.
///
/// For hover-based nodes like mouse, see `HoverSpace`.
///
/// `FocusSpace` only works with nodes compatible with the new I/O system introduced in Fluid 0.7.2.
class FocusSpace : Space, FocusIO {

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

    }

    this(Node[] nodes...) {

        super(nodes);
        findFocusBoxAction    = new FindFocusBoxAction(this);
        orderedFocusAction    = new OrderedFocusAction;
        positionalFocusAction = new PositionalFocusAction;

        // Track the current focus box
        findFocusBoxAction
            .then((Optional!Rectangle rect) => lastFocusBox = rect);

    }

    /// If a node inside `FocusSpace` triggers an input event (for example a keyboard node, 
    /// like a keyboard automaton), another node in the space may handle the event. This property
    /// will be set to true after that happens.
    ///
    /// This status is reset the moment this frame is updated again.
    ///
    /// Returns:
    ///     True, if an input action launched during the last frame was passed to a focused node and handled.
    bool wasInputHandled() const {

        return _wasInputHandled;

    }

    /// Params:
    ///     node = Node to check.
    /// Returns:
    ///     True if the node is currently focused by this space.
    bool isFocused(Node node) {
        return cast(Node) currentFocus == node;
    }

    override inout(Focusable) currentFocus() inout {
        return _focus;
    }

    override Focusable currentFocus(Focusable newFocus) {
        return _focus = newFocus;
    }

    override void resizeImpl(Vector2 space) {

        auto frame = implementIO!FocusSpace();

        use(actionIO);

        super.resizeImpl(space);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        auto frame = startBranchAction(findFocusBoxAction);

        _wasInputHandled = false;
        super.drawImpl(outer, inner);

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

        // Run the action, and mark input as handled
        if (_focus && _focus.actionImpl(actionID, isActive)) {
            _wasInputHandled = true;
            return true;
        }

        // Run local input actions
        if (runLocalInputActions(actionID, isActive)) {
            _wasInputHandled = true;
            return true;
        }
        
        return false;

    }

    /// ditto
    bool runInputAction(alias action)(bool isActive = true) {

        const id = inputActionID!action;

        return runInputAction(id, isActive);

    }

    /// Run an input action implemented by this node. These usually perform focus switching
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

    override void emitEvent(InputEvent event) {

        if (actionIO) {
            actionIO.emitEvent(event, &runInputAction);
        }

    }

}
