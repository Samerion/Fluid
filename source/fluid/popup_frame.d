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
/// This is a building block for other nodes, and may be difficult to use as a standalone node.
/// It requires an instance of [OverlayIO], which must be obtained with [Node.require]. For some
/// simpler cases, you can use [PopupButton][fluid.popup_button]: a button which will create and
/// operate a `PopupFrame` for you.
///
/// Popup needs [OverlayIO] to function, so it is an instance of [Overlayable].
class PopupFrame : InputNode!Frame, Overlayable, FocusIO, WithOrderedFocus, WithPositionalFocus {

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
        if (!toTakeFocus && !this.isFocused) {
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
        if (previousFocusable) {
            previousFocusable.focus();
        }
        else {
            focusIO.clearFocus();
        }
    }

    /// Returns:
    ///     True, if this popup (or its child) is currently focused.
    override bool isFocused() const {
        return childHasFocus
            || super.isFocused
            || (childPopup && childPopup.isFocused);
    }

    override Optional!Rectangle lastFocusBox() const {
        return _lastFocusBox;
    }

    override protected Optional!Rectangle lastFocusBox(Optional!Rectangle newFocusBox) {
        return _lastFocusBox = newFocusBox;
    }

    override inout(OrderedFocusAction) orderedFocusAction() inout {
        return _orderedFocusAction;
    }

    override inout(PositionalFocusAction) positionalFocusAction() inout {
        return _positionalFocusAction;
    }

    override final Rectangle getAnchor(Rectangle) const nothrow {
        return getAnchor;
    }

    private void resizeInternal(Node parent, Vector2 space) {
        parent.resizeChild(this, space);
    }

    protected override void resizeImpl(Vector2 space) {

        // Load FocusIO if available
        auto focusIO = require(this.focusIO);
        {
            auto io = this.implementIO();
            super.resizeImpl(space);
        }

        // The above resizeImpl call sets `focusIO` to `this`, it now needs to be restored
        this.focusIO = focusIO;

        // Immediately switch focus to self
        if (toTakeFocus) {
            previousFocusable = focusIO.currentFocus;
            focus();
            toTakeFocus = false;
        }
    }

    alias toRemove = typeof(super).toRemove;

    protected override void drawImpl(Rectangle outer, Rectangle inner) {
        auto action1 = this.startBranchAction(_findFocusBoxAction);
        auto action2 = this.startBranchAction(_markPopupButtonsAction);
        super.drawImpl(outer, inner);
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
        if (!focusIO.isFocused(this)) {
            return null;
        }
        return _currentFocus;
    }

    override Focusable currentFocus(Focusable newValue) {
        focusIO.currentFocus = this;
        return _currentFocus = newValue;
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
