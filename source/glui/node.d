///
module glui.node;

import raylib;

import glui.style;
import glui.utils;
import glui.structs;

/// Represents a Glui node.
abstract class GluiNode {

    public {

        /// Tree data for the node. Note: requires at least one draw before this will work.
        LayoutTree* tree;

        /// Layout for this node.
        Layout layout;

        /// If true, this node will be removed from the tree on the next draw.
        bool toRemove;

    }

    /// Minimum size of the node.
    protected auto minSize = Vector2(0, 0);

    private {

        /// If true, this node must update its size.
        bool _requiresResize = true;

        /// If true, this node is hidden and won't be rendered.
        bool _hidden;

        /// If true, this node is currently hovered.
        bool _hovered;

        /// Theme of this node.
        Theme _theme;

    }

    @property {

        /// Get the current theme.
        pragma(inline)
        const(Theme) theme() const { return _theme; }

        /// Set the theme.
        const(Theme) theme(const Theme value) {

            _theme = cast(Theme) value;
            reloadStyles();
            return _theme;

        }

    }

    @property {

        /// Check if the node is hidden.
        bool hidden() const { return _hidden; }

        /// Set the visibility
        bool hidden(bool value) {

            // If changed, trigger resize
            if (_hidden != value) updateSize();

            return _hidden = value;

        }

    }

    /// Params:
    ///     layout = Layout for this node.
    ///     theme = Theme of this node.
    this(Layout layout = Layout.init, Theme theme = null) {

        this.layout = layout;
        this.theme  = theme;
        this.tree   = new LayoutTree(this);

    }

    /// Ditto
    this(Theme theme = null, Layout layout = Layout.init) {

        this(layout, theme);

    }

    /// Ditto
    this() {

        this(Layout.init, null);

    }

    /// Show the node.
    final GluiNode show() {

        hidden = false;
        return this;

    }

    /// Hide the node.
    final GluiNode hide() {

        hidden = true;
        return this;

    }

    /// Toggle the node's visibility.
    final void toggleShow() { hidden = !hidden; }

    /// Remove this node from the tree before the next draw.
    final void remove() {

        hidden = true;
        toRemove = true;

    }

    /// Check if this node is hovered.
    @property
    bool hovered() const { return _hovered; }

    /// Recalculate the window size before next draw.
    ///
    /// Note: should be called or root; in case of children, will only work after the first draw.
    final void updateSize() {

        tree.root._requiresResize = true;

    }

    /// Draw this node as a root node.
    final void draw() {

        assert(theme, "Cannot draw a node lacking theme.");

        const space = Vector2(GetScreenWidth, GetScreenHeight);

        // Clear input
        tree.hover = null;

        // Resize if required
        if (IsWindowResized || _requiresResize) {

            resize(space);
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
        if (tree.focus) tree.keyboardHandled = tree.focus.keyboardImpl();
        else tree.keyboardHandled = false;

    }

    /// Draw this node at specified location.
    final protected void draw(Rectangle space) {

        import std.algorithm : min;

        // If hidden, don't draw anything
        if (hidden) return;

        const spaceV = Vector2(space.width, space.height);

        // Get parameters
        const size = Vector2(
            layout.nodeAlign[0] == NodeAlign.fill ? space.width  : min(space.width,  minSize.x),
            layout.nodeAlign[1] == NodeAlign.fill ? space.height : min(space.height, minSize.y),
        );
        const position = position(space, size);
        const rectangle = Rectangle(
            position.x, position.y,
            size.x,     size.y,
        );

        // If hovered
        _hovered = hoveredImpl(rectangle, GetMousePosition);
        if (_hovered) tree.hover = this;

        tree.pushScissors(rectangle);
        scope (exit) tree.popScissors();

        // Draw the node
        drawImpl(rectangle);

    }

    /// Recalculate the minimum node size and update the `minSize` property.
    /// Params:
    ///     space = Available space.
    protected final void resize(Vector2 space) {

        // The node is hidden, reset size
        if (hidden) minSize = Vector2(0, 0);

        // Otherwise perform like normal
        else resizeImpl(space);

    }

    /// Ditto
    ///
    /// This is the implementation of resizing to be provided by children.
    protected abstract void resizeImpl(Vector2 space);

    /// Draw this node.
    ///
    /// Note: Instead of directly accessing `style`, use `pickStyle` to enable temporarily changing styles as visual
    /// feedback. `resize` should still use the normal style.
    ///
    /// Params:
    ///     rect = Area the node should draw in.
    protected abstract void drawImpl(Rectangle rect);

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

        protected override bool hoveredImpl(Rectangle rect, Vector2 mousePosition) const {

            import glui.utils : contains;

            return rect.contains(mousePosition);

        }

    }

    /// Reload styles for the node. Triggered when the theme is changed.
    ///
    /// Use `mixin DefineStyles` to generate.
    protected abstract void reloadStyles() { }

    /// Get the current style.
    protected abstract const(Style) pickStyle() const;

    /// Get the node position.
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
            space.x + positionImpl(layout.nodeAlign[0], space.width  - usedSpace.x),
            space.y + positionImpl(layout.nodeAlign[1], space.height - usedSpace.y),
        );

    }

}
