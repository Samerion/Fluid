/// A [PopupFrame] displays above other nodes, and disappears when clicked outside. It can be
/// used to create context menus and tooltips.
///
/// Use [popupFrame] to build, and [spawnPopup] or [spawnChildPopup] to display.
module fluid.popup_frame;

import optional;

import std.traits;
import std.algorithm;

import fluid.node;
import fluid.tree;
import fluid.frame;
import fluid.input;
import fluid.style;
import fluid.utils;
import fluid.actions;
import fluid.backend;

import fluid.io.focus;
import fluid.io.action;
import fluid.io.overlay;

import fluid.future.action;
import fluid.future.context;
import fluid.future.branch_action;

@safe:

/// [nodeBuilder] for [PopupFrame]. Creates a vertical popup frame: its children will be laid out
/// in a column.
///
/// Once created, use [spawnPopup] to display, or [spawnChildPopup] if nested inside another
/// popup.
alias popupFrame = nodeBuilder!PopupFrame;

/// Spawn a new popup attached to the given tree. The popup automatically gains focus.
///
/// This is a legacy function. For new I/O, use [addPopup].
void spawnPopup(LayoutTree* tree, PopupFrame popup) {

    popup.tree = tree;

    // Set anchor
    popup.anchor = tree.focusBox;
    popup._anchorVec = Vector2(
        tree.focusBox.x,
        tree.focusBox.y + tree.focusBox.height
    );

    // Spawn the popup
    tree.queueAction(new PopupNodeAction(popup));
    tree.root.updateSize();

}

/// Spawn a new popup as a child of another. While the child is active, the parent will also
/// remain as such. The newly spawned popup automatically gains focus.
///
/// This is a legacy function. For new I/O, use [addChildPopup].
void spawnChildPopup(PopupFrame parent, PopupFrame popup) {

    auto tree = parent.tree;

    // Inherit theme from parent
    // TODO This may not work...
    if (!popup.theme)
        popup.theme = parent.theme;

    // Assign the child
    parent.childPopup = popup;

    // Spawn the popup
    spawnPopup(tree, popup);

}

/// Spawn a popup using [OverlayIO]. Popups have to be spawned
///
/// This function can be used to add new popups, or to open them again after they have been
/// closed.
///
/// Params:
///     overlayIO = `OverlayIO` instance to control to popup.
///     popup     = Popup frame to spawn.
///     anchor    = Box to attach the frame to;
///         likely a 0×0 rectangle at the mouse position for hover (mouse) events,
///         and the relevant `focusBox` for keyboard events.
///
///         For example, if the event was triggered by a button, through a keyboard key, then
///         the button's padding box ("outer box") will be the appropriate anchor.
/// See_Also:
///     [addChildPopup]
void addPopup(OverlayIO overlayIO, PopupFrame popup, Rectangle anchor) {
    popup.anchor = anchor;
    popup.toTakeFocus = true;
    overlayIO.addOverlay(popup, OverlayIO.types.context);
}

/// Spawn a new child popup using [OverlayIO].
///
/// Regular popups are mutually exclusive; only one can be open at a time. A child popup can
/// coexist with its parent. As long as the parent is open, so can be the child. The child can be
/// closed without closing the parent popup, but closing the parent popup will close the child.
///
/// Params:
///     overlayIO = `OverlayIO` instance to control to popup.
///     parent    = Parent popup.
///     popup     = Popup frame to spawn.
///     anchor    = Box to attach the popup frame to.
/// See_Also:
///     [addPopup] for spawning popups without a parent.
void addChildPopup(OverlayIO overlayIO, PopupFrame parent, PopupFrame popup, Rectangle anchor) {
    popup.anchor = anchor;
    popup.toTakeFocus = true;
    parent.childPopup = popup;
    overlayIO.addChildOverlay(parent, popup, OverlayIO.types.context);
}

/// A [Frame] which can be drawn in arbitrary position above other nodes.
///
/// `PopupFrame` will close when clicked outside (for [HoverIO] events). It tracks focus
/// separately from host [FocusIO], so it cannot be escaped with tab or arrow keys.
///
/// Popup needs [OverlayIO] to function, so it is an instance of [Overlayable].
class PopupFrame : InputNode!Frame, Overlayable, FocusIO, WithOrderedFocus, WithPositionalFocus {

    mixin makeHoverable;
    mixin enableInputActions;

    public {

        /// A child popup will keep this popup frame alive while it stays focused.
        ///
        /// Child popups can be spawned using [addChildPopup]. This allows both the parent and the
        /// child node to exist simultaneously! The typical usecase of this is to create submenus
        /// inside context menus.
        ///
        /// See_Also:
        ///     https://xkcd.com/1975/
        PopupFrame childPopup;

        /// Node that had focus before the popup frame took over. When the popup is closed using
        /// a [FluidInputAction.cancel] focus event, such as a keyboard shortcut, this node will
        /// take focus again.
        ///
        /// `previousFocus` is used only in the old backend, if [FocusIO] isn't available.
        /// See [previousFocusable] for the new I/O system.
        ///
        /// The [restorePreviousFocus] method can be used to bring this node back to focus.
        ///
        /// `previousFocus` is assigned automatically if [spawnPopup] or [spawnChildPopup] is
        /// used.
        ///
        /// See_Also:
        ///     [previousFocusable], which is used with the new I/O system.
        FluidFocusable previousFocus;

        /// Node that was focused before the popup was opened. Using [restorePreviousFocus], it
        /// can be given focus again, closing the popup. This is the default behavior for the
        /// escape key while a popup is open.
        ///
        /// Used if [FocusIO] is available.
        ///
        /// See_Also:
        ///     [previousFocus], which is used with the old backend system.
        Focusable previousFocusable;

        /// If true, the frame will claim focus on the next [resize][Node.updateSize]. This is
        /// used by the frame to gain focus when it is spawned, while respecting currently active
        /// `FocusIO`.
        ///
        /// This is automatically set to true by [addPopup] and [addChildPopup], and then set to
        /// false once used.
        bool toTakeFocus;

    }

    private {

        Rectangle _anchor;
        Vector2 _anchorVec;
        Focusable _currentFocus;
        Optional!Rectangle _lastFocusBox;

        OrderedFocusAction _orderedFocusAction;
        PositionalFocusAction _positionalFocusAction;
        FindFocusBoxAction _findFocusBoxAction;
        MarkPopupButtonsAction _markPopupButtonsAction;

        bool childHasFocus;

    }

    /// Create a PopupFrame. Takes an array of nodes to use as children.
    /// See [Frame] for details on how the children will be laid out.
    ///
    /// Params:
    ///     nodes = Child nodes of the frame.
    this(Node[] nodes...) {
        import fluid.structs : layout;

        super(nodes);
        this.layout = layout!"fill";
        this._orderedFocusAction     = new OrderedFocusAction;
        this._positionalFocusAction  = new PositionalFocusAction;
        this._findFocusBoxAction     = new FindFocusBoxAction(this);
        this._markPopupButtonsAction = new MarkPopupButtonsAction(this);

        _findFocusBoxAction
            .then((Optional!Rectangle result) => _lastFocusBox = result);
    }

    /// Set a new rectangular anchor.
    ///
    /// The anchor is used to specify the popup's position. The popup may appear below the
    /// `anchor`, above, next to it, or it may cover the anchor. The exact behavior depends
    /// on the [OverlayIO] system drawing the frame. Usually the direction is covered by the
    /// [layout][Node.layout] node property.
    ///
    /// For backwards compatibility, getting the rectangular anchor is currently done using
    /// [getAnchor].
    ///
    /// See_Also:
    ///     [getAnchor] to get the current anchor value.
    ///     [Overlayable.getAnchor] for information about how overlay anchors work in Fluid.
    /// Params:
    ///     value = Anchor to set.
    /// Returns:
    ///     Newly set anchor; same as passed in.
    Rectangle anchor(Rectangle value) nothrow {
        return _anchor = value;
    }

    /// Returns:
    ///     Currently set rectangular anchor.
    /// See_Also:
    ///     [anchor] for more information.
    final Rectangle getAnchor() const nothrow {
        return _anchor;
    }

    /// [PopupFrame] will automatically be marked for removal if not focused.
    ///
    /// For the new I/O, this is done by overriding the `toRemove` getter; the old backend does
    /// this from a tree action.
    ///
    /// Returns:
    ///     True if the `PopupFrame` has no focus (in new I/O only), or was manually marked
    ///     for removal.
    override bool toRemove() const {
        if (!toTakeFocus && usingFocusIO && !this.isFocused) {
            return true;
        }
        return super.toRemove;
    }

    /// Set [focus][FocusIO.currentFocus] to this frame, or to the first focusable child, if one
    /// exists.
    ///
    /// Note that [PopupFrame] tracks focus separately from the host [FocusIO]. The popup frame
    /// will become focused in the host, while the child will be focused in the popup frame.
    override void focus() {

        // Set focus to self
        super.focus();

        // Prefer if children get it, though
        this.focusRecurseChildren();

    }

    /// Give focus to whatever node had [focus][FocusIO.currentFocus] before this one.
    ///
    /// In new I/O, gives focus to [previousFocusable], and in the old backend, gives focus to
    /// [previousFocus]. If no node was focused, [clears focus][FocusIO.clearFocus].
    @(FluidInputAction.cancel)
    void restorePreviousFocus() {

        // Restore focus if possible
        if (previousFocusable) {
            previousFocusable.focus();
        }
        else if (previousFocus) {
            previousFocus.focus();
        }

        // Clear focus
        else if (usingFocusIO) {
            focusIO.clearFocus();
        }
        else tree.focus = null;

    }

    /// Returns:
    ///     True, if this popup (or its child) is currently focused.
    @property
    override bool isFocused() const {
        return childHasFocus
            || super.isFocused
            || (childPopup && childPopup.isFocused);
    }

    override Optional!Rectangle lastFocusBox() const {
        return _lastFocusBox;
    }

    override inout(OrderedFocusAction) orderedFocusAction() inout {
        return _orderedFocusAction;
    }

    override inout(PositionalFocusAction) positionalFocusAction() inout {
        return _positionalFocusAction;
    }

    /// Returns:
    ///     Position the frame is "anchored" to. A corner of the frame will be chosen to match
    ///     this position.
    deprecated("`Vector2 anchor` has been deprecated in favor of `Rectangle getAnchor` and "
        ~ "will be removed in Fluid 0.8.0.")
    final ref inout(Vector2) anchor() inout nothrow pure {
        return _anchorVec;
    }

    override final Rectangle getAnchor(Rectangle) const nothrow {
        return getAnchor;
    }

    // Intentionally left undocumented
    void drawAnchored(Node parent) {
        const rect = Rectangle(
            anchoredStartCorner.tupleof,
            minSize.tupleof
        );

        // Draw the node within the defined rectangle
        parent.drawChild(this, rect);
    }

    private void resizeInternal(Node parent, Vector2 space) {
        parent.resizeChild(this, space);
    }

    // Intentionally left undocumented
    Vector2 anchoredStartCorner() {
        const viewportSize = io.windowSize;

        // This method is very similar to MapSpace.getStartCorner, but simplified to handle the "automatic" case
        // only.

        // Define important points on the screen: center is our anchor, left is the other corner of the popup if we
        // extend it to the top-left, right is the other corner of the popup if we extend it to the bottom-right
        //  x--|    <- left
        //  |  |
        //  |--o--| <- center (anchor)
        //     |  |
        //     |--x <- right
        const left = _anchorVec - minSize;
        const center = _anchorVec;
        const right = _anchorVec + minSize;

        // Horizontal position
        const x

            // Default to extending towards the bottom-right, unless we overflow
            // |=============|
            // |   ↓ center  |
            // |   O------|  |
            // |   |      |  |
            // |   |      |  |
            // |   |------|  |
            // |=============|
            = right.x < viewportSize.x ? center.x

            // But in case we cannot fit the popup, we might need to reverse the direction
            // |=============|          |=============|
            // |             | ↓ right  | ↓ left      |
            // |        O------>        | <------O    |
            // |        |      |        | |      |    |
            // |        |      |        | |      |    |
            // |        |------|        | |------|    |
            // |=============|          |=============|
            : left.x >= 0 ? left.x

            // However, if we overflow either way, it's best we center the popup on the screen
            : (viewportSize.x - minSize.x) / 2;

        // Do the same for vertical position
        const y
            = right.y < viewportSize.y ? center.y
            : left.y >= 0 ? left.y
            : (viewportSize.y - minSize.y) / 2;

        return Vector2(x, y);

    }

    protected override void resizeImpl(Vector2 space) {

        // Load FocusIO if available
        if (auto focusIO = use(this.focusIO)) {

            {
                auto io = this.implementIO();
                super.resizeImpl(space);
            }

            // The above resizeImpl call sets `focusIO` to `this`, it now needs to be restored
            this.focusIO = focusIO;
        }

        // No FocusIO in use
        else super.resizeImpl(space);

        // Immediately switch focus to self
        if (usingFocusIO && toTakeFocus) {
            previousFocusable = focusIO.currentFocus;
            focus();
            toTakeFocus = false;
        }
    }

    alias toRemove = typeof(super).toRemove;

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        // Clear directional focus data; give the popup a separate context
        tree.focusDirection = FocusDirection(tree.focusDirection.lastFocusBox);

        auto action1 = this.startBranchAction(_findFocusBoxAction);
        auto action2 = this.startBranchAction(_markPopupButtonsAction);
        super.drawImpl(outer, inner);

        // Forcibly register previous & next focus if missing
        // The popup will register itself just after it gets drawn without this — and it'll be better if it doesn't
        if (tree.focusDirection.previous is null) {
            tree.focusDirection.previous = tree.focusDirection.last;
        }

        if (tree.focusDirection.next is null) {
            tree.focusDirection.next = tree.focusDirection.first;
        }

    }

    protected override bool actionImpl(IO io, int number, immutable InputActionID actionID,
        bool isActive)
    do {

        // Pass input events to whatever node is currently focused
        if (_currentFocus && _currentFocus.actionImpl(this, 0, actionID, isActive)) {
            return true;
        }

        // Handle events locally otherwise
        return this.runInputActionHandler(io, number, actionID, isActive);

    }

    protected override void mouseImpl() {

    }

    protected override bool focusImpl() {
        return _currentFocus && _currentFocus.focusImpl();
    }

    alias isFocused = typeof(super).isFocused;

    alias opEquals = typeof(super).opEquals;

    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

    override void emitEvent(InputEvent event) {
        assert(focusIO, "FocusIO is not loaded");
        focusIO.emitEvent(event);
    }

    override void typeText(scope const char[] text) {
        assert(focusIO, "FocusIO is not loaded");
        focusIO.typeText(text);
    }

    override char[] readText(return scope char[] buffer, ref int offset) {
        assert(focusIO, "FocusIO is not loaded");
        return focusIO.readText(buffer, offset);
    }

    override inout(Focusable) currentFocus() inout {
        if (usingFocusIO && !focusIO.isFocused(this)) {
            return null;
        }
        return _currentFocus;
    }

    override Focusable currentFocus(Focusable newValue) {
        if (usingFocusIO) {
            focusIO.currentFocus = this;
        }
        return _currentFocus = newValue;
    }

    private bool usingFocusIO() const nothrow {
        return focusIO && focusIO !is this;
    }

}

/// Tree action displaying a popup. This only applies to the legacy backend.
class PopupNodeAction : TreeAction {

    public {

        PopupFrame popup;

    }

    protected {

        /// Safety guard: Do not draw the popup if the tree hasn't resized.
        bool hasResized;

    }

    this(PopupFrame popup) {

        this.startNode = this.popup = popup;
        popup.show();
        popup.toRemove = false;

    }

    override void beforeResize(Node node, Vector2 viewportSize) {

        // Only accept root resizes
        if (node !is node.tree.root) return;

        // Perform the resize
        popup.resizeInternal(node, viewportSize);

        // First resize
        if (!hasResized) {

            // Give that popup focus
            popup.previousFocus = node.tree.focus;
            popup.focus();
            hasResized = true;

        }

    }

    /// Tree drawn, draw the popup now.
    override void afterTree() {

        // Don't draw without a resize
        if (!hasResized) return;

        // Stop if the popup requested removal
        if (popup.toRemove) { stop; return; }

        // Draw the popup
        popup.childHasFocus = false;
        popup.drawAnchored(popup.tree.root);

        // Remove the popup if it has no focus
        if (!popup.isFocused) {
            popup.remove();
            stop;
        }


    }

    override void afterDraw(Node node, Rectangle space) {

        import fluid.popup_button;

        // Require at least one resize to search for focus
        if (!hasResized) return;

        // Mark popup buttons
        if (auto button = cast(PopupButton) node) {

            button.parentPopup = popup;

        }

        // Ignore if a focused node has already been found
        if (popup.isFocused) return;

        const focusable = cast(FluidFocusable) node;

        if (focusable && focusable.isFocused) {

            popup.childHasFocus = focusable.isFocused;

        }

    }

    override void afterInput(ref bool keyboardHandled) {

        // Require at least one resize
        if (!hasResized) return;

        // Ignore if input was already handled
        if (keyboardHandled) return;

        // Ignore input in child popups
        if (popup.childPopup && popup.childPopup.isFocused) return;

        // Run actions for the popup
        keyboardHandled = popup.runFocusInputActions;

    }

}

/// This tree action will walk the branch to mark PopupButtons with the parent PopupFrame.
/// This is a temporary workaround to fill `PopupButton.parentPopup` in new I/O; starting with
/// 0.8.0 popup frames should implement `LayoutIO` to detect child popups.
private class MarkPopupButtonsAction : BranchAction {

    PopupFrame parent;

    this(PopupFrame parent) {
        this.parent = parent;
    }

    override void beforeDraw(Node node, Rectangle) {

        import fluid.popup_button;

        if (auto button = cast(PopupButton) node) {
            button.parentPopup = parent;
        }

    }

}
