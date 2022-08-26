///
module glui.node;

import raylib;

import std.math;
import std.traits;
import std.string;
import std.algorithm;

import glui.tree;
import glui.style;
import glui.utils;
import glui.input;
import glui.structs;

@safe:

private interface Styleable {

    /// Reload styles for the node. Triggered when the theme is changed.
    ///
    /// Use `mixin DefineStyles` to generate the styles.
    final void reloadStyles() {

        // First load what we're given
        reloadStylesImpl();

        // Then load the defaults
        loadDefaultStyles();

    }

    // Internal:

    protected void reloadStylesImpl();
    protected void loadDefaultStyles();

}

/// Represents a Glui node.
abstract class GluiNode : Styleable {

    /// This node defines a single style, `style`, which also works as a default style for all other nodes. However,
    /// rather than for that, the purpose of this style is to define the convention of `style` being the node's default,
    /// idle style.
    ///
    /// It should be noted the default `style` is the only style that affects a node's sizing — as the tree would have
    /// to be resized in case they changed and secondary styles are assumed to change frequently (for example, on
    /// hover). In practice, resizing the tree on those changes usually ends up horrible for the user, so it's advised
    /// to stick to constant sizing in order to not hurt the accessibility.
    mixin DefineStyles!(
        "style", q{ Style.init },
    );

    public {

        /// Tree data for the node. Note: requires at least one draw before this will work.
        LayoutTree* tree;

        /// Layout for this node.
        Layout layout;

        /// If true, this node will be removed from the tree on the next draw.
        bool toRemove;

        /// If true, mouse focus will be disabled for this node, so mouse signals will "go through" to its parents, as
        /// if the node wasn't there. The mouse will still detect hover like normal.
        bool ignoreMouse;

        deprecated("mousePass has been renamed to ignoreMouse and will be removed in 0.6.0")
        ref inout(bool) mousePass() inout { return ignoreMouse; }

    }

    /// Minimum size of the node.
    protected auto minSize = Vector2(0, 0);

    private {

        /// If true, this node must update its size.
        bool _requiresResize = true;

        /// If true, this node is hidden and won't be rendered.
        bool _isHidden;

        /// If true, this node is currently hovered.
        bool _isHovered;

        /// If true, this node is currently disabled.
        bool _isDisabled;

        /// Theme of this node.
        Theme _theme;

        /// Actions queued for this node; only used for queueing actions before the first `resize`; afterwards, all
        /// actions are queued directly into the tree.
        TreeAction[] _queuedActions;
        // TODO It might be helpful to expose an interface for queuing delegates to be done after resize

    }

    @property {

        /// Get the current theme.
        pragma(inline)
        const(Theme) theme() const { return _theme; }

        /// Set the theme.
        const(Theme) theme(const Theme value) @trusted {

            _theme = cast(Theme) value;
            reloadStyles();
            return _theme;

        }

    }

    @property {

        /// Check if the node is hidden.
        bool isHidden() const return { return _isHidden; }

        /// Set the visibility
        bool isHidden(bool value) return {

            // If changed, trigger resize
            if (_isHidden != value) updateSize();

            return _isHidden = value;

        }

        deprecated("hidden has been renamed to isHidden and will be removed in 0.6.0") {

            bool hidden() const { return _isHidden; }
            bool hidden(bool value) { return _isHidden = value; }

        }

    }

    /// Params:
    ///     layout = Layout for this node.
    ///     theme = Theme of this node.
    this(Layout layout = Layout.init, const Theme theme = null) {

        this.layout = layout;
        this.theme  = theme;

    }

    /// Ditto
    this(const Theme theme = null, Layout layout = Layout.init) {

        this(layout, theme);

    }

    /// Ditto
    this() {

        this(Layout.init, null);

    }

    /// Show the node.
    This show(this This = GluiNode)() return {

        // Note: The default value for This is necessary, otherwise virtual calls don't work
        isHidden = false;
        return cast(This) this;

    }

    /// Hide the node.
    This hide(this This = GluiNode)() return {

        isHidden = true;
        return cast(This) this;

    }

    /// Disable this node.
    This disable(this This = GluiNode)() return {

        isDisabled = true;
        return cast(This) this;

    }

    /// Enable this node.
    This enable(this This = GluiNode)() return {

        isDisabled = false;
        return cast(This) this;

    }

    /// Toggle the node's visibility.
    final void toggleShow() { isHidden = !isHidden; }

    /// Remove this node from the tree before the next draw.
    final void remove() {

        isHidden = true;
        toRemove = true;

    }

    /// Check if this node is hovered.
    ///
    /// Returns false if the node or, while the node is being drawn, some of its ancestors are disabled.
    @property
    bool isHovered() const { return _isHovered && !_isDisabled && !tree.isBranchDisabled; }

    deprecated("hovered has been renamed to isHovered and will be removed in 0.6.0.")
    bool hovered() const { return isHovered; }

    /// Check if this node is disabled.
    ref inout(bool) isDisabled() inout { return _isDisabled; }

    /// Check if this node is disabled.
    deprecated("disabled has been renamed to isDisabled and will be removed in 0.6.0.")
    ref inout(bool) disabled() inout { return isDisabled; }

    /// Checks if the node is disabled, either by self, or by any of its ancestors. Only works while the node is being
    /// drawn, and during `beforeDraw` and `afterDraw` tree actions.
    bool isDisabledInherited() const { return tree.isBranchDisabled; }

    /// Queue an action to perform within this node's branch.
    final void queueAction(TreeAction action) {

        // Set this node as the start for the given action
        action.startNode = this;

        // Insert the action into the tree's queue
        if (tree) tree.queueAction(action);

        // If there isn't a tree, wait for a resize
        else _queuedActions ~= action;

    }

    /// Recalculate the window size before next draw.
    final void updateSize() scope {

        if (tree) tree.root._requiresResize = true;
        // Tree might be null — if so, the node will be resized regardless

    }

    /// Draw this node as a root node.
    final void draw() @trusted {

        // No tree set
        if (tree is null) {

            // Create one
            tree = new LayoutTree(this);

            // Workaround for a HiDPI scissors mode glitch, which breaks Glui
            version (Glui_Raylib3)
            SetWindowSize(GetScreenWidth, GetScreenHeight);

        }

        // No theme set, set the default
        if (!theme) {

            import glui.default_theme;
            theme = gluiDefaultTheme;

        }

        version (Glui_Raylib3) const scale = hidpiScale();
        else                   const scale = Vector2(1, 1);

        const space = Vector2(GetScreenWidth / scale.x, GetScreenHeight / scale.y);

        // Clear mouse hover if LMB is up
        if (!isLMBHeld) tree.hover = null;

        // Clear focus info
        tree.focusDirection = FocusDirection(tree.focusBox);
        tree.focusBox = Rectangle(float.nan);

        // Resize if required
        if (IsWindowResized || _requiresResize) {

            resize(tree, theme, space);
            _requiresResize = false;

        }

        /// Area to render on
        const viewport = Rectangle(0, 0, space.x, space.y);


        // Run beforeTree actions
        tree.runAction(a => a.beforeTree(this, viewport));

        // Draw this node
        draw(viewport);

        // Run afterTree actions, remove those that have finished
        tree.runAction(a => a.afterTree());


        // Set mouse cursor to match hovered node
        if (tree.hover) {

            if (auto style = tree.hover.pickStyle) {

                SetMouseCursor(style.mouseCursor);

            }

        }


        // Note: pressed, not released; released activates input events, pressed activates focus
        const mousePressed = IsMouseButtonPressed(MouseButton.MOUSE_LEFT_BUTTON);

        // Mouse is hovering an input node
        if (auto hoverInput = cast(GluiHoverable) tree.hover) {

            // Ignore if the node is disabled
            if (!tree.hover.isDisabledInherited) {

                // Check if the node is focusable
                auto focusable = cast(GluiFocusable) tree.hover;

                // Pass the input to it
                hoverInput.mouseImpl();

                // If the left mouse button is pressed down, let it have focus, if it can
                if (mousePressed && focusable && !focusable.isFocused) focusable.focus();

            }

        }

        // Mouse pressed over a non-focusable node, remove focus
        else if (mousePressed) tree.focus = null;


        // Pass keyboard input to the currently focused node
        if (tree.focus && !tree.focus.asNode.isDisabledInherited) {

            tree.keyboardHandled = tree.focus.keyboardImpl();

        }
        else tree.keyboardHandled = false;


        // Keyboard wasn't handled
        if (!tree.keyboardHandled) {

            // Pressing tab
            if (IsKeyPressed(KeyboardKey.KEY_TAB)) {

                auto direction = tree.focusDirection;

                // Try switching focus
                auto focusTarget = IsKeyDown(KeyboardKey.KEY_LEFT_SHIFT)

                    // Requesting previous item
                    ? either(direction.previous, direction.last)

                    // Requesting next
                    : either(direction.next, direction.first);

                // Request focus
                focusTarget.focus();

            }

            // Check each direction we might
            else with (Style.Side) foreach (i, node; tree.focusDirection.positional) {

                // Ignore if there's no node in this direction
                if (node is null) continue;

                const pressed = i.predSwitch(
                    left,   KeyboardKey.KEY_LEFT,
                    right,  KeyboardKey.KEY_RIGHT,
                    top,    KeyboardKey.KEY_UP,
                    bottom, KeyboardKey.KEY_DOWN,
                ).IsKeyPressed;

                // If this key is pressed
                if (pressed) {

                    // Switch focus
                    node.focus();
                    break;

                }

            }

        }

    }

    /// Draw this node at the specified location from within of another (parent) node.
    ///
    /// The drawn node will be aligned according to the `layout` field within the box given.
    ///
    /// Params:
    ///     space = Space the node should be drawn in. It should be limited to space within the parent node.
    ///             If the node can't fit, it will be cropped.
    final protected void draw(Rectangle space) @trusted {

        assert(!toRemove, "A toRemove child wasn't removed from container.");
        assert(tree !is null, toString ~ " wasn't resized prior to drawing. You might be missing an `updateSize`"
            ~ " call!");

        // If hidden, don't draw anything
        if (isHidden) return;

        const spaceV = Vector2(space.width, space.height);

        // No style set? It likely hasn't been loaded
        if (!style) reloadStyles();

        // Get parameters
        const size = Vector2(
            layout.nodeAlign[0] == NodeAlign.fill ? space.width  : min(space.width,  minSize.x),
            layout.nodeAlign[1] == NodeAlign.fill ? space.height : min(space.height, minSize.y),
        );
        const position = position(space, size);

        // Calculate the boxes
        const marginBox  = Rectangle(position.tupleof, size.tupleof);
        const borderBox  = style ? style.cropBox(marginBox, style.margin)   : marginBox;
        const paddingBox = style ? style.cropBox(borderBox, style.border)   : borderBox;
        const contentBox = style ? style.cropBox(paddingBox, style.padding) : paddingBox;

        // If there's a border active, draw it
        const currentStyle = pickStyle;
        if (style && currentStyle && currentStyle.borderStyle) {

            currentStyle.borderStyle.apply(borderBox, style.border);

        }

        // Get the visible part of the padding box — so overflowed content doesn't get mouse focus
        const visibleBox = tree.intersectScissors(paddingBox);

        // Check if hovered
        _isHovered = hoveredImpl(visibleBox, GetMousePosition);

        // Check if the mouse stroke started this node
        const heldElsewhere = !IsMouseButtonPressed(MouseButton.MOUSE_LEFT_BUTTON)
            && isLMBHeld;

        // Update global hover unless mouse is being held down or mouse focus is disabled for this node
        if (isHovered && !heldElsewhere && !ignoreMouse) tree.hover = this;

        assert(
            [size.tupleof].all!isFinite,
            format!"Node %s resulting size is invalid: %s; given space = %s, minSize = %s"(
                typeid(this), size, space, minSize
            ),
        );
        assert(
            [paddingBox.tupleof, contentBox.tupleof].all!isFinite,
            format!"Node %s size is invalid: paddingBox = %s, contentBox = %s"(
                typeid(this), paddingBox, contentBox
            )
        );

        /// Descending into a disabled tree
        const branchDisabled = isDisabled || tree.isBranchDisabled;

        /// True if this node is disabled, and none of its ancestors are disabled
        const disabledRoot = isDisabled && !tree.isBranchDisabled;

        // Toggle disabled branch if we're owning the root
        if (disabledRoot) tree.isBranchDisabled = true;
        scope (exit) if (disabledRoot) tree.isBranchDisabled = false;

        // Count if disabled or not
        if (branchDisabled) tree._disabledDepth++;
        scope (exit) if (branchDisabled) tree._disabledDepth--;

        // Count depth
        tree.depth++;
        scope (exit) tree.depth--;

        // Run beforeDraw actions
        tree.runAction(a => a.beforeDrawImpl(this, space, paddingBox, contentBox));

        // Draw the node cropped
        // Note: minSize includes margin!
        if (minSize.x > space.width || minSize.y > space.height) {

            tree.pushScissors(paddingBox);
            scope (exit) tree.popScissors();

            drawImpl(paddingBox, contentBox);

        }

        // Draw the node
        else drawImpl(paddingBox, contentBox);


        // If not disabled
        if (!branchDisabled) {

            // Update focus info
            tree.focusDirection.update(this, space, tree.depth);

            // If this node is focused
            if (this is cast(GluiNode) tree.focus) {

                // Set the focus box
                tree.focusBox = space;

            }

        }

        // Run afterDraw actions
        tree.runAction(a => a.afterDraw(this, space, paddingBox, contentBox));

    }

    /// Recalculate the minimum node size and update the `minSize` property.
    /// Params:
    ///     tree  = The parent's tree to pass down to this node.
    ///     theme = Theme to inherit from the parent.
    ///     space = Available space.
    protected final void resize(LayoutTree* tree, const Theme theme, Vector2 space)
    in(tree, "Tree for Node.resize() must not be null.")
    in(theme, "Theme for Node.resize() must not be null.")
    do {

        // Inherit tree and theme
        this.tree = tree;
        if (this.theme is null) this.theme = theme;

        // Queue actions into the tree
        tree.actions ~= _queuedActions;
        _queuedActions = null;


        // The node is hidden, reset size
        if (isHidden) minSize = Vector2(0, 0);

        // Otherwise perform like normal
        else {

            import std.range;

            const fullMargin = style.fullMargin;
            const spacingX = style ? chain(fullMargin.sideX[], style.padding.sideX[]).sum : 0;
            const spacingY = style ? chain(fullMargin.sideY[], style.padding.sideY[]).sum : 0;

            // Reduce space by margins
            space.x = max(0, space.x - spacingX);
            space.y = max(0, space.y - spacingY);

            assert(
                space.x.isFinite && space.y.isFinite,
                format!"Internal error — Node %s was given infinite space: %s; spacing(x = %s, y = %s)"(typeid(this),
                    space, spacingX, spacingY)
            );

            // Resize the node
            resizeImpl(space);

            assert(
                minSize.x.isFinite && minSize.y.isFinite,
                format!"Node %s resizeImpl requested infinite minSize: %s"(typeid(this), minSize)
            );

            // Add margins
            minSize.x = ceil(minSize.x + spacingX);
            minSize.y = ceil(minSize.y + spacingY);

        }

        assert(
            minSize.x.isFinite && minSize.y.isFinite,
            format!"Internal error — Node %s returned invalid minSize %s"(typeid(this), minSize)
        );

    }

    /// Ditto
    ///
    /// This is the implementation of resizing to be provided by children.
    ///
    /// If style margins/paddings are non-zero, they are automatically subtracted from space, so they are handled
    /// automatically.
    protected abstract void resizeImpl(Vector2 space);

    /// Draw this node.
    ///
    /// Note: Instead of directly accessing `style`, use `pickStyle` to enable temporarily changing styles as visual
    /// feedback. `resize` should still use the normal style.
    ///
    /// Params:
    ///     paddingBox = Area which should be used by the node. It should include styling elements such as background,
    ///         but no content.
    ///     contentBox = Area which should be filled with content of the node, such as child nodes, text, etc.
    protected abstract void drawImpl(Rectangle paddingBox, Rectangle contentBox);

    /// Check if the node is hovered.
    ///
    /// This will be called right before drawImpl for each node in order to determine the which node should handle mouse
    /// input.
    ///
    /// If your node fills the rectangle area its given in `drawImpl`, you may use `mixin ImplHoveredRect` to implement
    /// this automatically.
    ///
    /// Params:
    ///     rect          = Area the node should be drawn in, as provided by drawImpl.
    ///     mousePosition = Current mouse position within the window.
    protected abstract bool hoveredImpl(Rectangle rect, Vector2 mousePosition) const;

    protected mixin template ImplHoveredRect() {

        private import raylib : Rectangle, Vector2;

        protected override bool hoveredImpl(Rectangle rect, Vector2 mousePosition) const {

            import glui.utils : contains;

            return rect.contains(mousePosition);

        }

    }

    /// Get the current style.
    protected abstract const(Style) pickStyle() const;

    /// Get the node's position in its space box.
    private Vector2 position(Rectangle space, Vector2 usedSpace) const {

        float positionImpl(NodeAlign align_, lazy float spaceLeft) {

            with (NodeAlign)
            final switch (align_) {

                case start, fill: return 0;
                case center: return spaceLeft / 2;
                case end: return spaceLeft;

            }

        }

        return Vector2(
            round(space.x + positionImpl(layout.nodeAlign[0], space.width  - usedSpace.x)),
            round(space.y + positionImpl(layout.nodeAlign[1], space.height - usedSpace.y)),
        );

    }

    private bool isLMBHeld() @trusted {

        const lmb = MouseButton.MOUSE_LEFT_BUTTON;
        return IsMouseButtonDown(lmb) || IsMouseButtonReleased(lmb);

    }

    override string toString() const {

        return format!"%s(%s)"(typeid(this), layout);

    }

}
