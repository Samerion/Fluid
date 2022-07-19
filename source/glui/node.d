///
module glui.node;

import raylib;

import std.math;
import std.traits;
import std.string;

import glui.style;
import glui.utils;
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

    /// Toggle the node's visibility.
    final void toggleShow() { isHidden = !isHidden; }

    /// Remove this node from the tree before the next draw.
    final void remove() {

        isHidden = true;
        toRemove = true;

    }

    /// Check if this node is hovered.
    ///
    /// Returns false if the node or some of its ancestors are disabled.
    @property
    bool isHovered() const { return _isHovered && !_isDisabled && !tree.disabledDepth; }

    deprecated("hovered has been renamed to isHovered and will be removed in 0.6.0.")
    bool hovered() const { return isHovered; }

    /// Check if this node is disabled.
    ref inout(bool) isDisabled() inout { return _isDisabled; }

    /// Check if this node is disabled.
    deprecated("disabled has been renamed to isDisabled and will be removed in 0.6.0.")
    ref inout(bool) disabled() inout { return isDisabled; }

    /// Checks if the node is disabled, either by self, or by any of its ancestors. Only works while the node is being
    /// drawn.
    protected bool isDisabledInherited() const { return tree.disabledDepth != 0; }

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
            SetWindowSize(GetScreenWidth, GetScreenHeight);

        }

        // No theme set, set the default
        if (!theme) {

            import glui.default_theme;
            theme = gluiDefaultTheme;

        }

        // Windows scales scissors mode regardless if we report that we support it or not
        version (Windows) const scale = GetWindowScaleDPI;
        else const scale = hidpiScale();

        const space = Vector2(GetScreenWidth / scale.x, GetScreenHeight / scale.y);

        // Clear mouse hover if LMB is up
        if (!isLMBHeld) tree.hover = null;


        // Resize if required
        if (IsWindowResized || _requiresResize) {

            resize(tree, theme, space);
            _requiresResize = false;

        }

        // Draw this node
        draw(Rectangle(0, 0, space.x, space.y));


        // Set mouse cursor to match hovered node
        if (tree.hover) {

            if (auto style = tree.hover.pickStyle) {

                SetMouseCursor(style.mouseCursor);

            }

        }


        // Note: pressed, not released; released activates input events, pressed activates focus
        const mousePressed = IsMouseButtonPressed(MouseButton.MOUSE_LEFT_BUTTON);

        // TODO: remove hover from disabled nodes (specifically to handle edgecase — node disabled while hovered and LMB
        // down)
        // TODO: move focus away from disabled nodes into neighbors along with #8

        // Mouse is hovering an input node
        if (auto hoverInput = cast(GluiFocusable) tree.hover) {

            // Pass the input to it
            hoverInput.mouseImpl();

            // If the left mouse button is pressed down, let it have focus
            if (mousePressed && !hoverInput.isFocused) hoverInput.focus();

        }

        // Mouse pressed over a non-focusable node, remove focus
        else if (mousePressed) tree.focus = null;


        // Pass keyboard input to the currently focused node
        if (tree.focus && !tree.focus.isDisabled) tree.keyboardHandled = tree.focus.keyboardImpl();
        else tree.keyboardHandled = false;

    }

    /// Draw this node at specified location.
    final protected void draw(Rectangle space) @trusted {

        // Given "space" is the amount of space we're given and what we should use at max.
        // Within this function, we deduce how much of the space we should actually use, and align the node
        // within the space.

        import std.algorithm : all, min, max, either;

        assert(!toRemove, "A toRemove child wasn't removed from container.");

        // If hidden, don't draw anything
        if (isHidden) return;

        const spaceV = Vector2(space.width, space.height);

        // No style set? Reload styles, the theme might've been set through CTFE
        if (!style) reloadStyles();

        // Get parameters
        const size = Vector2(
            layout.nodeAlign[0] == NodeAlign.fill ? space.width  : min(space.width,  minSize.x),
            layout.nodeAlign[1] == NodeAlign.fill ? space.height : min(space.height, minSize.y),
        );
        const position = position(space, size);

        // Calculate the boxes
        const marginBox = Rectangle(position.tupleof, size.tupleof);
        const borderBox = style ? style.cropBox(marginBox, style.margin) : marginBox;
        const paddingBox = style ? style.cropBox(borderBox, style.border) : borderBox;
        const contentBox = style ? style.cropBox(paddingBox, style.padding) : paddingBox;

        // If there's a border active, draw it
        const currentStyle = pickStyle;
        if (style && currentStyle && currentStyle.borderStyle) {

            pickStyle().borderStyle.apply(borderBox, style.border);

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

        // Descending into a disabled tree
        const incrementDisabled = isDisabled || tree.disabledDepth;

        // Count if disabled or not
        if (incrementDisabled) tree.disabledDepth++;
        scope (exit) if (incrementDisabled) tree.disabledDepth--;

        // Draw the node cropped
        // Note: minSize includes margin!
        if (minSize.x > space.width || minSize.y > space.height) {

            tree.pushScissors(paddingBox);
            scope (exit) tree.popScissors();

            drawImpl(paddingBox, contentBox);

        }

        // Draw the node
        else drawImpl(paddingBox, contentBox);

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

        // The node is hidden, reset size
        if (isHidden) minSize = Vector2(0, 0);

        // Otherwise perform like normal
        else {

            import std.range, std.algorithm;

            const fullMargin = style.fullMargin;
            const spacingX = style ? chain(fullMargin.sideX[], style.padding.sideX[]).sum : 0;
            const spacingY = style ? chain(fullMargin.sideY[], style.padding.sideY[]).sum : 0;

            // Reduce space by margins
            space.x = max(0, space.x - spacingX);
            space.y = max(0, space.y - spacingY);

            // Resize the node
            resizeImpl(space);

            // Add margins
            minSize.x = ceil(minSize.x + spacingX);
            minSize.y = ceil(minSize.y + spacingY);

        }

        assert(
            minSize.x.isFinite && minSize.y.isFinite,
            format!"Node %s returned invalid minSize %s"(typeid(this), minSize)
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
