///
module fluid.node;

import std.math;
import std.traits;
import std.string;
import std.algorithm;

import fluid.backend;
import fluid.tree;
import fluid.style;
import fluid.utils;
import fluid.input;
import fluid.actions;
import fluid.structs;
import fluid.theme : Breadcrumbs;

import fluid.io;
import fluid.future.context;


@safe:


/// Represents a Fluid node.
abstract class Node {

    public import fluid.structs : NodeAlign, Layout;
    public import fluid.structs : Align = NodeAlign;

    static class Extra {

        private struct CacheKey {

            size_t dataPtr;
            FluidBackend backend;

        }

        /// Styling texture cache, by image pointer.
        private TextureGC[CacheKey] cache;

        /// Load a texture from the image. May return null if there's no valid image.
        TextureGC* getTexture(FluidBackend backend, Image image) @trusted {

            // No image
            if (image.area == 0) return null;

            const key = CacheKey(cast(size_t) image.data.ptr, backend);

            // Find or create the entry
            return &cache.require(key, TextureGC(backend, image));

        }

    }

    public {

        /// Tree data for the node. Note: requires at least one draw before this will work.
        LayoutTree* tree;

        /// Layout for this node.
        Layout layout;

        /// Tags assigned for this node.
        TagList tags;

        /// Breadcrumbs assigned and applicable to this node. Loaded every resize and every draw.
        Breadcrumbs breadcrumbs;

        /// If true, this node will be removed from the tree on the next draw.
        bool toRemove;

        /// If true, mouse focus will be disabled for this node, so mouse signals will "go through" to its parents, as
        /// if the node wasn't there. The node will still detect hover like normal.
        bool ignoreMouse;

        /// True if the theme has been assigned explicitly by a direct assignment. If false, the node will instead
        /// inherit themes from the parent.
        ///
        /// This can be set to false to reset the theme.
        bool isThemeExplicit;

    }

    /// Minimum size of the node.
    protected auto minSize = Vector2(0, 0);

    private {

        /// If true, this node must update its size.
        bool _resizePending = true;

        /// If true, this node is hidden and won't be rendered.
        bool _isHidden;

        /// If true, this node is currently hovered.
        bool _isHovered;

        /// If true, this node is currently disabled.
        bool _isDisabled;

        /// Check if this node is disabled, or has inherited the status.
        bool _isDisabledInherited;

        /// Theme of this node.
        Theme _theme;

        /// Cached style for this node.
        Style _style;

        /// Attached styling delegates.
        Rule.StyleDelegate[] _styleDelegates;

        /// Actions queued for this node; only used for queueing actions before the first `resize`; afterwards, all
        /// actions are queued directly into the tree.
        TreeAction[] _queuedActions;

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

    }

    /// Construct a new node.
    ///
    /// The typical approach to constructing new nodes is via `fluid.utils.simpleConstructor`. A node component would
    /// provide an alias pointing to the `simpleConstructor` instance, which can then be used as a factory function. For
    /// example, `Label` provides the `label` simpleConstructor. Using these has increased convenience by making it
    /// possible to specify special properties while constructing the node, for example
    ///
    /// ---
    /// auto myLabel = label(.layout!1, .theme, "Hello, World!");
    /// // Equivalent of:
    /// auto myLabel = new Label("Hello, World!");
    /// myLabel.layout = .layout!1;
    /// myLabel.theme = .theme;
    /// ---
    ///
    /// See_Also:
    ///     `fluid.utils.simpleConstructor`
    this() { }

    /// Returns: True if both nodes are the same node.
    override bool opEquals(const Object other) const @safe {

        return this is other;

    }

    /// ditto
    bool opEquals(const Node otherNode) const {

        return this is otherNode;

    }

    /// The theme defines how the node will appear to the user.
    ///
    /// Themes affect the node and its children, and can respond to changes in state,
    /// like values changing or user interaction.
    /// 
    /// If no theme has been set, a default one will be provided and used automatically.
    ///
    /// See `Theme` for more information.
    ///
    /// Returns: Currently active theme.
    /// Params:
    ///     newValue = Change the current theme.
    inout(Theme) theme() inout { return _theme; }

    /// Set the theme.
    Theme theme(Theme value) {

        isThemeExplicit = true;
        updateSize();
        return _theme = value;

    }

    /// Nodes automatically inherit theme from their parent, and the root node implictly inherits the default theme.
    /// An explicitly-set theme will override any inherited themes recursively, stopping at nodes that also have themes 
    /// set explicitly.
    /// Params:
    ///     value = Theme to inherit.
    /// See_Also: `theme`
    void inheritTheme(Theme value) {

        // Do not override explicitly-set themes
        if (isThemeExplicit) return;

        _theme = value;
        updateSize();

    }

    @("Themes can be changed at runtime https://git.samerion.com/Samerion/Fluid/issues/114")
    unittest {

        import fluid.frame;

        auto theme1 = nullTheme.derive(
            rule!Frame(
                Rule.backgroundColor = color("#000"),
            ),
        );
        auto theme2 = nullTheme.derive(
            rule!Frame(
                Rule.backgroundColor = color("#fff"),
            ),
        );

        auto deepFrame = vframe();
        auto blackFrame = vframe(theme1);
        auto root = vframe(
            theme1,
            vframe(
                vframe(deepFrame),
            ),
            vframe(blackFrame),
        );

        root.draw();
        assert(deepFrame.pickStyle.backgroundColor == color("#000"));
        assert(blackFrame.pickStyle.backgroundColor == color("#000"));
        root.theme = theme2;
        root.draw();
        assert(deepFrame.pickStyle.backgroundColor == color("#fff"));
        assert(blackFrame.pickStyle.backgroundColor == color("#000"));

    }

    /// Clear the currently assigned theme
    void resetTheme() {

        _theme = Theme.init;
        isThemeExplicit = false;
        updateSize();

    }

    /// Current style, used for sizing. Does not include any changes made by `when` clauses or callbacks.
    ///
    /// Direct changes are discouraged, and are likely to be discarded when reloading themes. Use themes instead.
    ref inout(Style) style() inout { return _style; }

    /// Show the node.
    This show(this This = Node)() return {

        // Note: The default value for This is necessary, otherwise virtual calls don't work
        isHidden = false;
        return cast(This) this;

    }

    /// Hide the node.
    This hide(this This = Node)() return {

        isHidden = true;
        return cast(This) this;

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = new class Node {

            override void resizeImpl(Vector2) {
                minSize = Vector2(10, 10);
            }

            override void drawImpl(Rectangle outer, Rectangle inner) {
                io.drawRectangle(inner, color!"123");
            }

        };

        root.io = io;
        root.theme = nullTheme;
        root.draw();

        io.assertRectangle(Rectangle(0, 0, 10, 10), color!"123");
        io.nextFrame;

        // Hide the node now
        root.hide();
        root.draw();

        assert(io.rectangles.empty);

    }

    /// Disable this node.
    This disable(this This = Node)() {

        // `scope return` attribute on disable() and enable() is broken, `isDisabled` just can't get return for reasons
        // unknown

        isDisabled = true;
        return cast(This) this;

    }

    /// Enable this node.
    This enable(this This = Node)() {

        isDisabled = false;
        return cast(This) this;

    }

    unittest {

        import fluid.space;
        import fluid.button;
        import fluid.text_input;

        int submitted;

        auto io = new HeadlessBackend;
        auto button = fluid.button.button("Hello!", delegate { submitted++; });
        auto input = fluid.textInput("Placeholder", delegate { submitted++; });
        auto root = vspace(button, input);

        root.io = io;
        root.draw();

        // Press the button
        {
            io.nextFrame;
            io.press(KeyboardKey.enter);
            button.focus();
            root.draw();

            assert(submitted == 1);
        }

        // Press the button while disabled
        {
            io.nextFrame;
            io.press(KeyboardKey.enter);
            button.disable();
            root.draw();

            assert(button.isDisabled);
            assert(submitted == 1, "Button shouldn't trigger again");
        }

        // Enable the button and hit it again
        {
            io.nextFrame;
            io.press(KeyboardKey.enter);
            button.enable();
            root.draw();

            assert(!button.isDisabledInherited);
            assert(submitted == 2);
        }

        // Try typing into the input box
        {
            io.nextFrame;
            io.release(KeyboardKey.enter);
            io.inputCharacter("Hello, ");
            input.focus();
            root.draw();

            assert(input.value == "Hello, ");
        }

        // Disable the box and try typing again
        {
            io.nextFrame;
            io.inputCharacter("World!");
            input.disable();
            root.draw();

            assert(input.value == "Hello, ", "Input should remain unchanged");
        }

        // Attempt disabling the nodes recursively
        {
            io.nextFrame;
            io.press(KeyboardKey.enter);
            button.focus();
            input.enable();
            root.disable();
            root.draw();

            assert(root.isDisabled);
            assert(!button.isDisabled);
            assert(!input.isDisabled);
            assert(button.isDisabledInherited);
            assert(input.isDisabledInherited);
            assert(submitted == 2);
        }

        // Check the input box
        {
            io.nextFrame;
            io.press(KeyboardKey.enter);
            io.inputCharacter("World!");
            input.focus();

            root.draw();

            assert(submitted == 2);
            assert(input.value == "Hello, ");
        }

        // Enable input once again
        {
            io.nextFrame;
            io.press(KeyboardKey.enter);
            root.enable();
            root.draw();

            assert(submitted == 3);
            assert(input.value == "Hello, ");
        }

    }

    inout(FluidBackend) backend() inout {

        return tree.backend;

    }

    FluidBackend backend(FluidBackend backend) {

        // Create the tree if not present
        if (tree is null) {

            tree = new LayoutTree(this, backend);
            return backend;

        }

        else return tree.backend = backend;

    }

    alias io = backend;

    /// Toggle the node's visibility.
    final void toggleShow() {

        isHidden = !isHidden;

    }

    /// Remove this node from the tree before the next draw.
    final void remove() {

        isHidden = true;
        toRemove = true;

    }

    /// Get the minimum size of this node.
    final Vector2 getMinSize() const {

        return minSize;

    }

    /// Check if this node is hovered.
    ///
    /// Returns false if the node or, while the node is being drawn, some of its ancestors are disabled.
    @property
    bool isHovered() const { return _isHovered && !_isDisabled && !tree.isBranchDisabled; }

    /// Check if this node is disabled.
    ref inout(bool) isDisabled() inout { return _isDisabled; }

    /// Checks if the node is disabled, either by self, or by any of its ancestors. Updated when drawn.
    bool isDisabledInherited() const { return _isDisabledInherited; }

    /// Apply all of the given node parameters on this node.
    ///
    /// This can be used to activate node parameters after the node has been constructed,
    /// or inside of a node constructor.
    ///
    /// Note: 
    ///     Due to language limitations, this function has to be called with the dot operator, like `this.applyAll()`.
    /// Params:
    ///     params = Node parameters to activate.
    void applyAll(this This, Parameters...)(Parameters params) {

        cast(void) .applyAll(cast(This) this, params);

    }

    /// Applying parameters from inside of a node constructor.
    @("Node parameters can be applied with `applyAll` during construction")
    unittest {

        class MyNode : Node {

            this() {
                this.applyAll(
                    .layout!"fill",
                );
            }

            override void resizeImpl(Vector2) { }
            override void drawImpl(Rectangle, Rectangle) { }

        }

        auto myNode = new MyNode;

        assert(myNode.layout == .layout!"fill");
        
    }

    /// Queue an action to perform within this node's branch.
    ///
    /// This is recommended to use over `LayoutTree.queueAction`, as it can be used to limit the action to a specific
    /// branch, and can also work before the first draw.
    ///
    /// This function is not safe to use while the tree is being drawn.
    final void queueAction(TreeAction action)
    in (action, "Invalid action queued (null)")
    do {

        // Set this node as the start for the given action
        action.startNode = this;

        // Reset the action
        action.toStop = false;

        // Insert the action into the tree's queue
        if (tree) tree.queueAction(action);

        // If there isn't a tree, wait for a resize
        else _queuedActions ~= action;

    }

    @system unittest {

        import fluid.space;

        Node[4] allNodes;
        Node[] visitedNodes;

        auto io = new HeadlessBackend;
        auto root = allNodes[0] = vspace(
            allNodes[1] = hspace(
                allNodes[2] = hspace(),
            ),
            allNodes[3] = hspace(),
        );
        auto action = new class TreeAction {

            override void beforeDraw(Node node, Rectangle) {

                visitedNodes ~= node;

            }

        };

        // Queue the action before creating the tree
        root.queueAction(action);

        // Assign the backend; note this would create a tree
        root.io = io;

        root.draw();

        assert(visitedNodes == allNodes);

        // Clear visited nodes
        io.nextFrame;
        visitedNodes = [];
        action.toStop = false;

        // Queue an action in a branch
        allNodes[1].queueAction(action);

        root.draw();

        assert(visitedNodes[].equal(allNodes[1..3]));

    }

    /// True if this node is pending a resize.
    bool resizePending() const {

        return _resizePending;

    }

    /// Recalculate the window size before next draw.
    final void updateSize() scope {

        if (tree) tree.root._resizePending = true;
        // Tree might be null — if so, the node will be resized regardless

    }

    unittest {

        int resizes;

        auto io = new HeadlessBackend;
        auto root = new class Node {

            override void resizeImpl(Vector2) {

                resizes++;

            }
            override void drawImpl(Rectangle, Rectangle) { }

        };

        root.io = io;
        assert(resizes == 0);

        // Resizes are only done on request
        foreach (i; 0..10) {

            root.draw();
            assert(resizes == 1);
            io.nextFrame;

        }

        // Perform such a request
        root.updateSize();
        assert(resizes == 1);

        // Resize will be done right before next draw
        root.draw();
        assert(resizes == 2);
        io.nextFrame;

        // This prevents unnecessary resizes if multiple things change in a single branch
        root.updateSize();
        root.updateSize();

        root.draw();
        assert(resizes == 3);
        io.nextFrame;

        // Another draw, no more resizes
        root.draw();
        assert(resizes == 3);

    }

    /// Draw this node as a root node.
    final void draw() @trusted {

        // No tree set, create one
        if (tree is null) {

            tree = new LayoutTree(this);

        }

        // No theme set, set the default
        if (!theme) {

            import fluid.default_theme;
            inheritTheme(fluidDefaultTheme);

        }

        assert(theme);

        const space = tree.io.windowSize;

        // Clear mouse hover if LMB is up
        if (!isLMBHeld) tree.hover = null;

        // Clear scroll
        tree.scroll = null;

        // Clear focus info
        tree.focusDirection = FocusDirection(tree.focusBox);
        tree.focusBox = Rectangle(float.nan);

        // Clear breadcrumbs
        tree.breadcrumbs = Breadcrumbs.init;

        // Update input
        tree.poll();

        // Request a resize if the window was resized
        if (tree.io.hasJustResized) updateSize();

        // Resize if required
        if (resizePending) {

            resizeInternalImpl(tree, theme, space);
            _resizePending = false;

        }

        /// Area to render on
        const viewport = Rectangle(0, 0, space.x, space.y);


        // Run beforeTree actions
        foreach (action; tree.filterActions) {

            action.beforeTree(this, viewport);

        }

        // Draw this node
        drawInternalImpl(viewport);

        // Run afterTree actions
        foreach (action; tree.filterActions) {

            action.afterTree();

        }


        // Set mouse cursor to match hovered node
        if (tree.hover) {

            tree.io.mouseCursor = tree.hover.pickStyle().mouseCursor;

        }


        // Note: pressed, not released; released activates input events, pressed activates focus
        const mousePressed = tree.io.isPressed(MouseButton.left)
            || tree.io.isPressed(MouseButton.right)
            || tree.io.isPressed(MouseButton.middle);

        // Update scroll input
        if (tree.scroll) tree.scroll.scrollImpl(io.scroll);

        // Mouse is hovering an input node
        // Note that nodes will remain in tree.hover if LMB is pressed to prevent "hover slipping" — actions should
        // only trigger if the button was both pressed and released on the node.
        if (auto hoverInput = cast(FluidHoverable) tree.hover) {

            // Pass input to the node, unless it's disabled
            if (!tree.hover.isDisabledInherited) {

                // Check if the node is focusable
                auto focusable = cast(FluidFocusable) tree.hover;

                // If the left mouse button is pressed down, give the node focus
                if (mousePressed && focusable) focusable.focus();

                // Pass the input to it
                hoverInput.runMouseInputActions || hoverInput.mouseImpl;

            }

        }

        // Mouse pressed over a non-focusable node, remove focus
        else if (mousePressed) tree.focus = null;


        // Pass keyboard input to the currently focused node
        if (tree.focus && !tree.focus.asNode.isDisabledInherited) {

            // TODO BUG: also fires for removed nodes

            // Let it handle input
            tree.wasKeyboardHandled = either(
                tree.focus.runFocusInputActions,
                tree.focus.focusImpl,
            );

        }

        // Nothing has focus
        else with (FluidInputAction)
        tree.wasKeyboardHandled = {

            // Check the first focusable node
            if (auto first = tree.focusDirection.first) {

                // Check for focus action
                const focusFirst = tree.isFocusActive!(FluidInputAction.focusNext)
                    || tree.isFocusActive!(FluidInputAction.focusDown)
                    || tree.isFocusActive!(FluidInputAction.focusRight)
                    || tree.isFocusActive!(FluidInputAction.focusLeft);

                // Switch focus
                if (focusFirst) {

                    first.focus();
                    return true;

                }

            }

            // Or maybe, get the last focusable node
            if (auto last = tree.focusDirection.last) {

                // Check for focus action
                const focusLast = tree.isFocusActive!(FluidInputAction.focusPrevious)
                    || tree.isFocusActive!(FluidInputAction.focusUp);

                // Switch focus
                if (focusLast) {

                    last.focus();
                    return true;

                }

            }

            return false;

        }();

        foreach (action; tree.filterActions) {

            action.afterInput(tree.wasKeyboardHandled);

        }

    }

    unittest {

        import fluid.space;
        import fluid.button;

        auto io = new HeadlessBackend;
        auto root = vspace(
            button("1", delegate { }),
            button("2", delegate { }),
            button("3", delegate { }),
        );

        root.io = io;

        root.draw();

        assert(root.tree.focus is null);

        // Autofocus first
        {

            io.nextFrame;
            io.press(KeyboardKey.tab);
            root.draw();

            // Fluid will automatically try to find the first focusable node
            assert(root.tree.focus.asNode is root.children[0]);

            io.nextFrame;
            io.release(KeyboardKey.tab);
            root.draw();

            assert(root.tree.focus.asNode is root.children[0]);

        }

        // Tab into the next node
        {

            io.nextFrame;
            io.press(KeyboardKey.tab);
            root.draw();
            io.release(KeyboardKey.tab);

            assert(root.tree.focus.asNode is root.children[1]);

        }

        // Autofocus last
        {
            root.tree.focus = null;

            io.nextFrame;
            io.press(KeyboardKey.leftShift);
            io.press(KeyboardKey.tab);
            root.draw();

            // If left-shift tab is pressed, the last focusable node will be used
            assert(root.tree.focus.asNode is root.children[$-1]);

            io.nextFrame;
            io.release(KeyboardKey.leftShift);
            io.release(KeyboardKey.tab);
            root.draw();

            assert(root.tree.focus.asNode is root.children[$-1]);

        }

    }

    /// Draw a child node at the specified location inside of this node.
    ///
    /// Before drawing a node, it must first be resized. This should be done ahead of time in `resizeImpl`.
    /// Use `updateSize()` to cause it to be called before the next draw call.
    ///
    /// Params:
    ///     child = Child to draw.
    ///     space = Space to place the node in.
    ///         The drawn node will be aligned inside the given box according to its `layout` field.
    protected void drawChild(Node child, Rectangle space) {

        child.drawInternalImpl(space);

    }

    /// Draw this node at the specified location from within of another (parent) node.
    ///
    /// The drawn node will be aligned according to the `layout` field within the box given.
    ///
    /// Params:
    ///     space = Space the node should be drawn in. It should be limited to space within the parent node.
    ///             If the node can't fit, it will be cropped.
    deprecated("`Node.draw` has been replaced with `drawChild(Node, Rectangle)` and will be removed in Fluid 0.8.0.")
    final protected void draw(Rectangle space) {

        drawInternalImpl(space);

    }

    final private void drawInternalImpl(Rectangle space) @trusted {

        import std.range;

        assert(!toRemove, "A toRemove child wasn't removed from container.");
        assert(tree !is null, toString ~ " wasn't resized prior to drawing. You might be missing an `updateSize`"
            ~ " call!");

        // If hidden, don't draw anything
        if (isHidden) return;

        const spaceV = Vector2(space.width, space.height);

        // Get parameters
        const size = Vector2(
            layout.nodeAlign[0] == NodeAlign.fill ? space.width  : min(space.width,  minSize.x),
            layout.nodeAlign[1] == NodeAlign.fill ? space.height : min(space.height, minSize.y),
        );
        const position = position(space, size);

        // Calculate the boxes
        const marginBox  = Rectangle(position.tupleof, size.tupleof);
        const borderBox  = style.cropBox(marginBox, style.margin);
        const paddingBox = style.cropBox(borderBox, style.border);
        const contentBox = style.cropBox(paddingBox, style.padding);
        const mainBox    = borderBox;

        // Load breadcrumbs from the tree
        breadcrumbs = tree.breadcrumbs;
        auto currentStyle = pickStyle();

        // Write dynamic breadcrumbs to the tree
        // Restore when done
        tree.breadcrumbs ~= currentStyle.breadcrumbs;
        scope (exit) tree.breadcrumbs = breadcrumbs;

        // Get the visible part of the padding box — so overflowed content doesn't get mouse focus
        const visibleBox = tree.intersectScissors(paddingBox);

        // Check if hovered
        _isHovered = hoveredImpl(visibleBox, tree.io.mousePosition);

        // Set tint
        auto previousTint = io.tint;
        io.tint = multiply(previousTint, currentStyle.tint);
        scope (exit) io.tint = previousTint;

        // If there's a border active, draw it
        if (currentStyle.borderStyle) {

            currentStyle.borderStyle.apply(io, borderBox, style.border);
            // TODO wouldn't it be better to draw borders as background?

        }

        // Check if the mouse stroke started this node
        const heldElsewhere = !tree.io.isPressed(MouseButton.left)
            && isLMBHeld;

        // Check for hover, unless ignored by this node
        if (isHovered && !ignoreMouse) {

            // Set global hover as long as the mouse isn't held down
            if (!heldElsewhere) tree.hover = this;

            // Update scroll
            if (auto scrollable = cast(FluidScrollable) this) {

                // Only if scrolling is possible
                if (scrollable.canScroll(io.scroll))  {

                    tree.scroll = scrollable;

                }

            }

        }

        assert(
            only(size.tupleof).all!isFinite,
            format!"Node %s resulting size is invalid: %s; given space = %s, minSize = %s"(
                typeid(this), size, space, minSize
            ),
        );
        assert(
            only(mainBox.tupleof, contentBox.tupleof).all!isFinite,
            format!"Node %s size is invalid: borderBox = %s, contentBox = %s"(
                typeid(this), mainBox, contentBox
            )
        );

        /// Descending into a disabled tree
        const branchDisabled = isDisabled || tree.isBranchDisabled;

        /// True if this node is disabled, and none of its ancestors are disabled
        const disabledRoot = isDisabled && !tree.isBranchDisabled;

        // Toggle disabled branch if we're owning the root
        if (disabledRoot) tree.isBranchDisabled = true;
        scope (exit) if (disabledRoot) tree.isBranchDisabled = false;

        // Save disabled status
        _isDisabledInherited = branchDisabled;

        // Count depth
        tree.depth++;
        scope (exit) tree.depth--;

        // Run beforeDraw actions
        foreach (action; tree.filterActions) {

            action.beforeDrawImpl(this, space, mainBox, contentBox);

        }

        // Draw the node cropped
        // Note: minSize includes margin!
        if (minSize.x > space.width || minSize.y > space.height) {

            const lastScissors = tree.pushScissors(mainBox);
            scope (exit) tree.popScissors(lastScissors);

            drawImpl(mainBox, contentBox);

        }

        // Draw the node
        else drawImpl(mainBox, contentBox);


        // If not disabled
        if (!branchDisabled) {

            const focusBox = focusBoxImpl(contentBox);

            // Update focus info
            tree.focusDirection.update(this, focusBox, tree.depth);

            // If this node is focused
            if (this is cast(Node) tree.focus) {

                // Set the focus box
                tree.focusBox = focusBox;

            }

        }

        // Run afterDraw actions
        foreach (action; tree.filterActions) {

            action.afterDrawImpl(this, space, mainBox, contentBox);

        }

    }

    /// Resize a child of this node.
    /// Params:
    ///     child = Child node to resize.
    ///     space = Maximum space available for the child to use.
    /// Returns:
    ///     Space allocated by the child node.
    protected Vector2 resizeChild(Node child, Vector2 space) {

        child.resizeInternalImpl(tree, theme, space);

        return child.minSize;

    }

    /// Recalculate the minimum node size and update the `minSize` property.
    /// Params:
    ///     tree  = The parent's tree to pass down to this node.
    ///     theme = Theme to inherit from the parent.
    ///     space = Available space.
    deprecated("`Node.resize` has been replaced with `resizeChild(Node, Vector2)` and will be removed in Fluid 0.8.0.")
    protected final void resize(LayoutTree* tree, Theme theme, Vector2 space)
    in(tree, "Tree for Node.resize() must not be null.")
    in(theme, "Theme for Node.resize() must not be null.")
    do {

        resizeInternalImpl(tree, theme, space);

    }

    private final void resizeInternalImpl(LayoutTree* tree, Theme theme, Vector2 space)
    in(tree, "Tree for Node.resize() must not be null.")
    in(theme, "Theme for Node.resize() must not be null.")
    do {

        // Inherit tree and theme
        this.tree = tree;
        inheritTheme(theme);

        // Load breadcrumbs from the tree
        breadcrumbs = tree.breadcrumbs;

        // Load the theme
        reloadStyles();

        // Write breadcrumbs into the tree
        tree.breadcrumbs ~= _style.breadcrumbs;
        scope (exit) tree.breadcrumbs = breadcrumbs;

        // Queue actions into the tree
        tree.actions ~= _queuedActions;
        _queuedActions = null;


        // The node is hidden, reset size
        if (isHidden) minSize = Vector2(0, 0);

        // Otherwise perform like normal
        else {

            import std.range;

            const fullMargin = style.fullMargin;
            const spacingX = chain(fullMargin.sideX[], style.padding.sideX[]).sum;
            const spacingY = chain(fullMargin.sideY[], style.padding.sideY[]).sum;

            // Reduce space by margins
            space.x = max(0, space.x - spacingX);
            space.y = max(0, space.y - spacingY);

            assert(
                space.x.isFinite && space.y.isFinite,
                format!"Internal error — Node %s was given infinite space: %s; spacing(x = %s, y = %s)"(typeid(this),
                    space, spacingX, spacingY)
            );

            // Run beforeResize actions
            foreach (action; tree.filterActions) {

                action.beforeResize(this, space);

            }

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

    /// Switch to the previous or next focused item
    @(FluidInputAction.focusPrevious,FluidInputAction.focusNext)
    protected void focusPreviousOrNext(FluidInputAction actionType) {

        auto direction = tree.focusDirection;

        // Get the node to switch to
        auto node = actionType == FluidInputAction.focusPrevious

            // Requesting previous item
            ? either(direction.previous, direction.last)

            // Requesting next
            : either(direction.next, direction.first);

        // Switch focus
        if (node) node.focus();

    }

    /// Switch focus towards a specified direction.
    @(FluidInputAction.focusLeft, FluidInputAction.focusRight)
    @(FluidInputAction.focusUp, FluidInputAction.focusDown)
    protected void focusInDirection(FluidInputAction action) {

        with (FluidInputAction) {

            // Check which side we're going
            const side = action.predSwitch(
                focusLeft,  Style.Side.left,
                focusRight, Style.Side.right,
                focusUp,    Style.Side.top,
                focusDown,  Style.Side.bottom,
            );

            // Get the node
            auto node = tree.focusDirection.positional[side];

            // Switch focus to the node
            if (node !is null) node.focus();

        }

    }

    /// Connect to an I/O system
    protected T use(T : IO)()
    in (tree, "`use()` should only be used inside `resizeImpl`")
    do {
        return tree.context.io.get!T();
    }

    /// ditto
    protected T use(T : IO)(out T io)
    in (tree, "`use()` should only be used inside `resizeImpl`")
    do {
        return io = use!T();
    }

    /// Require
    protected T require(T : IO)()
    in (tree, "`require()` should only be used inside `resizeImpl`")
    do {
        auto io = use!T();
        assert(io, "require: Requested I/O " ~ T.stringof ~ " is not active");
        return io;
    }

    /// ditto
    protected T require(T : IO)(out T io)
    in (tree, "`require()` should only be used inside `resizeImpl`")
    do {
        return io = require!T();
    }

    /// Load a resource associated with the given I/O. 
    ///
    /// The resource should be continuously loaded during `resizeImpl`. Even if a resource has already been loaded,
    /// it has to be declared with `load` so the I/O system knows it is still in use.
    ///
    /// ---
    /// CanvasIO canvasIO;
    /// DrawableImage image;
    /// void resizeImpl(Vector2 space) {
    ///     require(canvasIO);
    ///     load(canvasIO, image);
    /// }
    /// ---
    /// 
    /// Params:
    ///   io = 
    ///   resource = 
    /// Returns: 
    protected T load(T, I : IO)(I io, ref T resource) {

        // Load the resource
        const id = io.load(resource);

        // Pass data into the resource
        resource.load(io, id);

        return resource;

    }

    /// Enable I/O interfaces implemented by this node.
    // TODO elaborate
    /// Returns:
    ///     A [RAII](https://en.wikipedia.org/wiki/Resource_acquisition_is_initialization) struct that disables
    ///     these interfaces on destruction.
    protected auto implementIO(this This)() {

        import std.meta : AliasSeq, Filter;

        // mustuse is not available in LDC 1.28
        static if (__traits(compiles, { import core.attribute : mustuse; }))
            import core.attribute : mustuse;
        else
            alias mustuse = AliasSeq!();

        alias IOs = Filter!(isIO, InterfacesTuple!This);
        alias IOArray = IO[IOs.length];

        IOArray ios;

        static foreach (i, IO; IOs) {
            ios[i] = tree.context.io.replace(ioID!IO, cast(This) this);
        }

        @mustuse
        static struct Close {
            private LayoutTree* tree;
            IOArray ios;
            ~this() {
                static foreach (i, IO; IOs) {
                    tree.context.io.replace(ioID!IO, ios[i]);
                }
            }
        }

        return Close(tree, ios);

    }

    /// This is the implementation of resizing to be provided by children.
    ///
    /// If style margins/paddings are non-zero, they are automatically subtracted from space, so they are handled
    /// automatically.
    protected abstract void resizeImpl(Vector2 space);

    /// Draw this node.
    ///
    /// Tip: Instead of directly accessing `style`, use `pickStyle` to enable temporarily changing styles as visual
    ///     feedback. `resize` should still use the normal style.
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
    /// The default behavior considers the entire area of the node to be "hoverable".
    ///
    /// Params:
    ///     rect          = Area the node should be drawn in, as provided by drawImpl.
    ///     mousePosition = Current mouse position within the window.
    protected bool hoveredImpl(Rectangle rect, Vector2 mousePosition) {

        return rect.contains(mousePosition);

    }

    alias ImplHoveredRect = implHoveredRect;

    deprecated("implHoveredRect is now the default behavior; implHoveredRect is to be removed in 0.8.0")
    protected mixin template implHoveredRect() {

        private import fluid.backend : Rectangle, Vector2;

        protected override bool hoveredImpl(Rectangle rect, Vector2 mousePosition) const {

            import fluid.utils : contains;

            return rect.contains(mousePosition);

        }

    }

    /// The focus box defines the *focused* part of the node. This is relevant in nodes which may have a selectable 
    /// subset, such as a dropdown box, which may be more important at present moment (selected). Scrolling actions 
    /// like `scrollIntoView` will use the focus box to make sure the selected area is presented to the user.
    /// Returns: The focus box of the node. 
    Rectangle focusBoxImpl(Rectangle inner) const {

        return inner;

    }

    /// Get the current style.
    Style pickStyle() {

        // Pick the current style
        auto result = _style;

        // Load style from breadcrumbs
        // Note breadcrumbs may change while drawing, but should also be able to affect sizing
        // For this reason static breadcrumbs are applied both when reloading and when picking
        breadcrumbs.applyStatic(this, result);

        // Run delegates
        foreach (dg; _styleDelegates) {

            dg(this).apply(this, result);

        }

        // Load dynamic breadcrumb styles
        breadcrumbs.applyDynamic(this, result);

        return result;

    }

    /// Reload style from the current theme.
    protected void reloadStyles() {

        import fluid.typeface;

        // Reset style
        _style = Style.init;

        // Apply theme to the given style
        _styleDelegates = theme.apply(this, _style);

        // Apply breadcrumbs
        breadcrumbs.applyStatic(this, _style);

        // Update size
        updateSize();

    }

    /// Get the node's position in its  box.
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

    @system  // catching Error
    unittest {

        import std.exception;
        import core.exception;
        import fluid.frame;

        static class Square : Frame {
            @safe:
            Color color;
            this(Color color) {
                this.color = color;
            }
            override void resizeImpl(Vector2) {
                minSize = Vector2(100, 100);
            }
            override void drawImpl(Rectangle, Rectangle inner) {
                io.drawRectangle(inner, color);
            }
        }

        alias square = simpleConstructor!Square;

        auto io = new HeadlessBackend;
        auto colors = [
            color!"7ff0a5",
            color!"17cccc",
            color!"a6a415",
            color!"cd24cf",
        ];
        auto root = vframe(
            .layout!"fill",
            square(.layout!"start",  colors[0]),
            square(.layout!"center", colors[1]),
            square(.layout!"end",    colors[2]),
            square(.layout!"fill",   colors[3]),
        );

        root.theme = Theme.init.derive(
            rule!Frame(Rule.backgroundColor = color!"1c1c1c")
        );
        root.io = io;

        // Test the layout
        {

            root.draw();

            // Each square in order
            io.assertRectangle(Rectangle(0, 0, 100, 100), colors[0]);
            io.assertRectangle(Rectangle(350, 100, 100, 100), colors[1]);
            io.assertRectangle(Rectangle(700, 200, 100, 100), colors[2]);

            // Except the last one, which is turned into a rectangle by "fill"
            // A proper rectangle class would change its target rectangles to keep aspect ratio
            io.assertRectangle(Rectangle(0, 300, 800, 100), colors[3]);

        }

        // Now do the same, but expand each node
        {

            io.nextFrame;

            foreach (child; root.children) {
                child.layout.expand = 1;
            }

            root.draw().assertThrown!AssertError;  // Oops, forgot to resize!
            root.updateSize;
            root.draw();

            io.assertRectangle(Rectangle(0, 0, 100, 100), colors[0]);
            io.assertRectangle(Rectangle(350, 175, 100, 100), colors[1]);
            io.assertRectangle(Rectangle(700, 350, 100, 100), colors[2]);
            io.assertRectangle(Rectangle(0, 450, 800, 150), colors[3]);

        }

        // Change Y alignment
        {

            io.nextFrame;

            root.children[0].layout = .layout!(1, "start", "end");
            root.children[1].layout = .layout!(1, "center", "fill");
            root.children[2].layout = .layout!(1, "end", "start");
            root.children[3].layout = .layout!(1, "fill", "center");

            root.updateSize;
            root.draw();

            io.assertRectangle(Rectangle(0, 50, 100, 100), colors[0]);
            io.assertRectangle(Rectangle(350, 150, 100, 150), colors[1]);
            io.assertRectangle(Rectangle(700, 300, 100, 100), colors[2]);
            io.assertRectangle(Rectangle(0, 475, 800, 100), colors[3]);

        }

        // Try different expand values
        {

            io.nextFrame;

            root.children[0].layout = .layout!(0, "center", "fill");
            root.children[1].layout = .layout!(1, "center", "fill");
            root.children[2].layout = .layout!(2, "center", "fill");
            root.children[3].layout = .layout!(3, "center", "fill");

            root.updateSize;
            root.draw();

            // The first rectangle doesn't expand so it should be exactly 100×100 in size
            io.assertRectangle(Rectangle(350, 0, 100, 100), colors[0]);

            // The remaining space is 500px, so divided into 1+2+3=6 pieces, it should be about 83.33px per piece
            io.assertRectangle(Rectangle(350, 100.00, 100,  83.33), colors[1]);
            io.assertRectangle(Rectangle(350, 183.33, 100, 166.66), colors[2]);
            io.assertRectangle(Rectangle(350, 350.00, 100, 250.00), colors[3]);

        }

    }

    private bool isLMBHeld() @trusted {

        return tree.io.isDown(MouseButton.left)
            || tree.io.isReleased(MouseButton.left);

    }

    override string toString() const {

        return format!"%s(%s)"(typeid(this), layout);

    }

}

/// Start a Fluid GUI app.
/// 
/// This is meant to be the easiest way to launch a Fluid app. Call this in your `main()` function with the node holding
/// your user interface, and that's it! The function will not return until the app is closed. 
///
/// ---
/// void main() {
///     
///     run(
///         label("Hello, World!"),
///     );
/// 
/// }
/// ---
///
/// You can close the UI programmatically by calling `remove()` on the root node.
///
/// The exact behavior of this function is defined by the backend in use, so some functionality may vary. Some backends
/// might not support this.
/// 
/// Params:
///     node = This node will serve as the root of your user interface until closed. If you wish to change it at 
///         runtime, wrap it in a `NodeSlot`.
void run(Node node) {

    if (mockRun) {
        mockRun()(node);
        return;
    }

    auto backend = cast(FluidEntrypointBackend) defaultFluidBackend;

    assert(backend, "Chosen default backend does not expose an event loop interface.");

    node.io = backend;
    backend.run(node);
    
}

/// ditto
void run(Node node, FluidEntrypointBackend backend) {

    // Mock run callback is available
    if (mockRun) {
        mockRun()(node);
    }

    else {
        node.io = backend;
        backend.run(node);
    }

}

alias RunCallback = void delegate(Node node) @safe;

/// Set a new function to use instead of `run`.
RunCallback mockRun(RunCallback callback) {

    // Assign the callback
    mockRun() = callback;
    return mockRun();

}

ref RunCallback mockRun() {

    static RunCallback callback;
    return callback;

}
