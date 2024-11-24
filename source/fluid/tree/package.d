module fluid.tree;

import std.conv;
import std.math;
import std.container;
import std.algorithm;

import fluid.node;
import fluid.style;
import fluid.backend;

import fluid.io.focus;
import fluid.io.scroll;

public import fluid.tree.input_action;
public import fluid.tree.input_mapping;


@safe:


version (OSX)
    version = Fluid_MacKeyboard;


/// A class for iterating over the node tree.
abstract class TreeAction {

    public {

        /// Node to descend into; `beforeDraw` and `afterDraw` will only be emitted for this node and its children.
        ///
        /// May be null to enable iteration over the entire tree.
        Node startNode;

        /// If true, this action is complete and no callbacks should be ran.
        ///
        /// Overloads of the same callbacks will still be called for the event that prompted stopping.
        bool toStop;

    }

    private {

        /// Set to true once the action has descended into `startNode`.
        bool startNodeFound;

    }

    /// Stop the action
    final void stop() {

        toStop = true;

    }

    /// Called before the tree is drawn. Keep in mind this might not be called if the action is started when tree
    /// iteration has already begun.
    /// Params:
    ///     root     = Root of the tree.
    ///     viewport = Screen space for the node.
    void beforeTree(Node root, Rectangle viewport) { }

    /// Called before a node is resized.
    void beforeResize(Node node, Vector2 viewportSpace) { }

    /// Called before each `drawImpl` call of any node in the tree, so supplying parent nodes before their children.
    ///
    /// This might not be called if the node is offscreen. If you need to find all nodes, try `beforeResize`.
    ///
    /// Params:
    ///     node       = Node that's about to be drawn.
    ///     space      = Space given for the node.
    ///     paddingBox = Padding box of the node.
    ///     contentBox = Content box of teh node.
    void beforeDraw(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) { }

    /// ditto
    void beforeDraw(Node node, Rectangle space) { }

    /// internal
    final void beforeDrawImpl(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) {

        // There is a start node set
        if (startNode !is null) {

            // Check if we're descending into its branch
            if (node is startNode) startNodeFound = true;

            // Continue only if it was found
            else if (!startNodeFound) return;

        }

        // Call the hooks
        beforeDraw(node, space, paddingBox, contentBox);
        beforeDraw(node, space);

    }

    /// Called after each `drawImpl` call of any node in the tree, so supplying children nodes before their parents.
    ///
    /// This might not be called if the node is offscreen. If you need to find all nodes, try `beforeResize`.
    ///
    /// Params:
    ///     node       = Node that's about to be drawn.
    ///     space      = Space given for the node.
    ///     paddingBox = Padding box of the node.
    ///     contentBox = Content box of teh node.
    void afterDraw(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) { }

    /// ditto
    void afterDraw(Node node, Rectangle space) { }

    /// internal
    final void afterDrawImpl(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) {

        // There is a start node set
        if (startNode !is null) {

            // Check if we're leaving the node
            if (node is startNode) startNodeFound = false;

            // Continue only if it was found
            else if (!startNodeFound) return;
            // Note: We still emit afterDraw for that node, hence `else if`

        }

        afterDraw(node, space, paddingBox, contentBox);
        afterDraw(node, space);
    }

    /// Called after the tree is drawn. Called before input events, so they can assume actions have completed.
    ///
    /// By default, calls `stop()` preventing the action from evaluating during next draw.
    void afterTree() {

        stop();

    }

    /// Hook that triggers after processing input. Useful if post-processing is necessary to, perhaps, implement
    /// fallback input.
    ///
    /// Warning: This will **not trigger** unless `afterTree` is overrided not to stop the action. If you make use of
    /// this, make sure to make the action stop in this method.
    ///
    /// Params:
    ///     keyboardHandled = If true, keyboard input was handled. Passed by reference, so if you react to input, change
    ///         this to true.
    void afterInput(ref bool keyboardHandled) { }

}

/// Global data for the layout tree.
struct LayoutTree {

    import fluid.theme : Breadcrumbs;

    // Nodes
    public {

        /// Root node of the tree.
        Node root;

        /// Node the mouse is hovering over if any. 
        ///
        /// This is the last — topmost — node in the tree with `isHovered` set to true.
        Node hover;

        /// Currently focused node.
        ///
        /// Changing this value directly is discouraged. Some nodes might not want the focus! Be gentle, call
        /// `FluidFocusable.focus()` instead and let the node set the value on its own.
        FluidFocusable focus;

        /// Deepest hovered scrollable node.
        FluidScrollable scroll;

    }

    // Input
    public {

        /// Focus direction data.
        FocusDirection focusDirection;

        /// Padding box of the currently focused node. Only available after the node has been drawn.
        ///
        /// See_also: `focusDirection.lastFocusBox`.
        Rectangle focusBox;

        /// Tree actions queued to execute during next draw.
        DList!TreeAction actions;

        /// Input strokes bound to emit given action signals.
        ///
        /// Input layers have to be sorted.
        InputLayer[] boundInputs;

        invariant(boundInputs.isSorted);

        /// Actions that are currently held down.
        DList!InputBinding downActions;

        /// Actions that have just triggered.
        DList!InputBinding activeActions;

        /// Access to core input and output facilities.
        FluidBackend backend;
        alias io = backend;

        /// True if keyboard input was handled during the last frame; updated after tree rendering has completed.
        bool wasKeyboardHandled;

        deprecated("keyboardHandled was renamed to wasKeyboardHandled and will be removed in Fluid 0.8.0.") 
        alias keyboardHandled = wasKeyboardHandled;

    }

    /// Miscelleanous, technical properties.
    public {

        /// Current node drawing depth.
        uint depth;

        /// Current rectangle drawing is limited to.
        Rectangle scissors;

        /// True if the current tree branch is marked as disabled (doesn't take input).
        bool isBranchDisabled;

        /// Current breadcrumbs. These are assigned to any node that is resized or drawn at the time.
        ///
        /// Any node that introduces its own breadcrumbs will push onto this stack, and pop once finished.
        Breadcrumbs breadcrumbs;

    }

    /// Incremented for every `filterActions` access to prevent nested accesses from breaking previously made ranges.
    private int _actionAccessCounter;

    /// Create a new tree with the given node as its root, and using the given backend for I/O.
    this(Node root, FluidBackend backend) {

        this.root = root;
        this.backend = backend;
        this.restoreDefaultInputBinds();

    }

    /// Create a new tree with the given node as its root. Use the default backend, if any is present.
    this(Node root) {

        this(root, defaultFluidBackend);

        assert(backend, "Cannot create LayoutTree; no backend was chosen, and no default is set.");

    }

    /// Returns true if this branch requested a resize or is pending a resize.
    bool resizePending() const {

        return root.resizePending;

    }

    /// Returns: True if the mouse is currently hovering a node in the tree.
    bool isHovered() const {

        return hover !is null;

    }

    /// Queue an action to perform while iterating the tree.
    ///
    /// Avoid using this; most of the time `Node.queueAction` is what you want. `LayoutTree.queueAction` might fire
    /// too early
    void queueAction(TreeAction action)
    in (action, "Invalid action queued")
    do {

        actions ~= action;

    }

    /// Restore defaults for given actions.
    void restoreDefaultInputBinds() {

        /// Get the ID of an input action.
        auto bind(alias a, T)(T arg) {

            return InputBinding(inputActionID!a, InputStroke.Item(arg));

        }

        with (FluidInputAction) {

            // System-independent keys
            auto universalShift = InputLayer(
                InputStroke(KeyboardKey.leftShift),
                [
                    bind!focusPrevious(KeyboardKey.tab),
                    bind!entryPrevious(KeyboardKey.tab),
                    bind!outdent(KeyboardKey.tab),
                    bind!selectPreviousChar(KeyboardKey.left),
                    bind!selectNextChar(KeyboardKey.right),
                    bind!selectPreviousLine(KeyboardKey.up),
                    bind!selectNextLine(KeyboardKey.down),
                    bind!selectToLineStart(KeyboardKey.home),
                    bind!selectToLineEnd(KeyboardKey.end),
                    bind!breakLine(KeyboardKey.enter),
                    bind!contextMenu(KeyboardKey.f10),
                ]
            );
            auto universal = InputLayer(
                InputStroke(),
                [
                    // Press
                    bind!press(MouseButton.left),
                    bind!press(KeyboardKey.enter),
                    bind!press(GamepadButton.cross),

                    // Submit
                    bind!submit(KeyboardKey.enter),
                    bind!submit(GamepadButton.cross),

                    // Cancel
                    bind!cancel(KeyboardKey.escape),
                    bind!cancel(GamepadButton.circle),

                    // Menu
                    bind!contextMenu(MouseButton.right),
                    bind!contextMenu(KeyboardKey.contextMenu),

                    // Tabbing; index-focus
                    bind!focusPrevious(GamepadButton.leftButton),
                    bind!focusNext(KeyboardKey.tab),
                    bind!focusNext(GamepadButton.rightButton),

                    // Directional focus
                    bind!focusLeft(KeyboardKey.left),
                    bind!focusLeft(GamepadButton.dpadLeft),
                    bind!focusRight(KeyboardKey.right),
                    bind!focusRight(GamepadButton.dpadRight),
                    bind!focusUp(KeyboardKey.up),
                    bind!focusUp(GamepadButton.dpadUp),
                    bind!focusDown(KeyboardKey.down),
                    bind!focusDown(GamepadButton.dpadDown),

                    // Text input
                    bind!backspace(KeyboardKey.backspace),
                    bind!deleteChar(KeyboardKey.delete_),
                    bind!breakLine(KeyboardKey.enter),
                    bind!previousChar(KeyboardKey.left),
                    bind!nextChar(KeyboardKey.right),
                    bind!previousLine(KeyboardKey.up),
                    bind!nextLine(KeyboardKey.down),
                    bind!entryPrevious(KeyboardKey.up),
                    bind!entryPrevious(GamepadButton.dpadUp),
                    bind!entryNext(KeyboardKey.down),
                    bind!entryNext(KeyboardKey.tab),
                    bind!entryNext(GamepadButton.dpadDown),
                    bind!toLineStart(KeyboardKey.home),
                    bind!toLineEnd(KeyboardKey.end),
                    bind!insertTab(KeyboardKey.tab),

                    // Scrolling
                    bind!scrollLeft(KeyboardKey.left),
                    bind!scrollLeft(GamepadButton.dpadLeft),
                    bind!scrollRight(KeyboardKey.right),
                    bind!scrollRight(GamepadButton.dpadRight),
                    bind!scrollUp(KeyboardKey.up),
                    bind!scrollUp(GamepadButton.dpadUp),
                    bind!scrollDown(KeyboardKey.down),
                    bind!scrollDown(GamepadButton.dpadDown),
                    bind!pageUp(KeyboardKey.pageUp),
                    bind!pageDown(KeyboardKey.pageDown),
                ]
            );

            // TODO universal left/right key
            version (Fluid_MacKeyboard)
                boundInputs = [

                    // Shift + Command
                    InputLayer(
                        InputStroke(KeyboardKey.leftShift, KeyboardKey.leftSuper),
                        [
                            // TODO Command should *expand selection* on macOS instead of current
                            // toLineStart/toLineEnd behavior
                            bind!selectToLineStart(KeyboardKey.left),
                            bind!selectToLineEnd(KeyboardKey.right),
                            bind!selectToStart(KeyboardKey.up),
                            bind!selectToEnd(KeyboardKey.down),
                            bind!redo(KeyboardKey.z),
                        ]
                    ),

                    // Shift + Option
                    InputLayer(
                        InputStroke(KeyboardKey.leftShift, KeyboardKey.leftAlt),
                        [
                            bind!selectPreviousWord(KeyboardKey.left),
                            bind!selectNextWord(KeyboardKey.right),
                        ]
                    ),

                    // Command
                    InputLayer(
                        InputStroke(KeyboardKey.leftSuper),
                        [
                            bind!toLineStart(KeyboardKey.left),
                            bind!toLineEnd(KeyboardKey.right),
                            bind!toStart(KeyboardKey.up),
                            bind!toEnd(KeyboardKey.down),
                            bind!selectAll(KeyboardKey.a),
                            bind!copy(KeyboardKey.c),
                            bind!cut(KeyboardKey.x),
                            bind!paste(KeyboardKey.v),
                            bind!undo(KeyboardKey.z),
                            bind!redo(KeyboardKey.y),
                            bind!submit(KeyboardKey.enter),
                        ]
                    ),

                    // Option
                    InputLayer(
                        InputStroke(KeyboardKey.leftAlt),
                        [
                            bind!deleteWord(KeyboardKey.delete_),
                            bind!backspaceWord(KeyboardKey.backspace),
                            bind!previousWord(KeyboardKey.left),
                            bind!nextWord(KeyboardKey.right),
                        ]
                    ),

                    // Control
                    InputLayer(
                        InputStroke(KeyboardKey.leftControl),
                        [
                            bind!backspaceWord(KeyboardKey.w),  // emacs & vim
                            bind!entryPrevious(KeyboardKey.k),  // vim
                            bind!entryPrevious(KeyboardKey.p),  // emacs
                            bind!entryNext(KeyboardKey.j),  // vim
                            bind!entryNext(KeyboardKey.n),  // emacs
                        ]
                    ),

                    universalShift,
                    universal,
                ];
            else
                boundInputs = [

                    InputLayer(
                        InputStroke(KeyboardKey.leftShift, KeyboardKey.leftControl),
                        [
                            bind!selectPreviousWord(KeyboardKey.left),
                            bind!selectNextWord(KeyboardKey.right),
                            bind!selectToStart(KeyboardKey.home),
                            bind!selectToEnd(KeyboardKey.end),
                            bind!redo(KeyboardKey.z),
                        ]
                    ),

                    InputLayer(
                        InputStroke(KeyboardKey.leftControl),
                        [
                            bind!deleteWord(KeyboardKey.delete_),
                            bind!backspaceWord(KeyboardKey.backspace),
                            bind!backspaceWord(KeyboardKey.w),  // emacs & vim
                            bind!entryPrevious(KeyboardKey.k),  // vim
                            bind!entryPrevious(KeyboardKey.p),  // emacs
                            bind!entryNext(KeyboardKey.j),  // vim
                            bind!entryNext(KeyboardKey.n),  // emacs
                            bind!previousWord(KeyboardKey.left),
                            bind!nextWord(KeyboardKey.right),
                            bind!selectAll(KeyboardKey.a),
                            bind!copy(KeyboardKey.c),
                            bind!cut(KeyboardKey.x),
                            bind!paste(KeyboardKey.v),
                            bind!undo(KeyboardKey.z),
                            bind!redo(KeyboardKey.y),
                            bind!toStart(KeyboardKey.home),
                            bind!toEnd(KeyboardKey.end),

                            // Submit with ctrl+enter
                            bind!submit(KeyboardKey.enter),
                        ]
                    ),

                    InputLayer(
                        InputStroke(KeyboardKey.leftAlt),
                        [
                            bind!entryUp(KeyboardKey.up),
                        ]
                    ),

                    universalShift,
                    universal,

                ];

        }

    }

    /// Remove any inputs bound to given input action.
    /// Returns: `true` if the action was cleared.
    bool clearBoundInput(InputActionID action) {

        import std.array;

        // TODO test

        bool found;

        foreach (ref layer; boundInputs) {

            const oldLength = layer.bindings.length;

            layer.bindings = layer.bindings.filter!(a => a.action == action).array;

            if (layer.bindings.length != oldLength) {
                found = true;
            }

        }

        return found;

    }

    /// Find a layer for the given input stroke.
    /// Returns: Layer found for the given input stroke. `null` if none found.
    inout(InputLayer)* layerForStroke(InputStroke stroke) inout scope return {

        auto modifiers = stroke.modifiers;

        foreach (i, layer; boundInputs) {

            // Found a matching layer
            if (modifiers == layer.modifiers) {

                return &boundInputs[i];

            }

            // Stop if other layers are less complex
            if (modifiers.length > layer.modifiers.length) break;

        }

        return null;

    }

    /// Bind a key stroke or button to given input action. Multiple key strokes are allowed to match given action.
    void bindInput(InputActionID action, InputStroke stroke)
    in (stroke.length != 0)
    do {

        // TODO tests

        auto binding = InputBinding(action, stroke.input[$-1]);

        // Layer exists, add the binding
        if (auto layer = layerForStroke(stroke)) {

            layer.bindings ~= binding;

        }

        // Layer doesn't exist, create it
        else {

            auto modifiers = stroke.modifiers;
            auto newLayer = InputLayer(modifiers, [binding]);
            bool found;

            // Insert the layer before any layer that is less complex
            foreach (i, layer; boundInputs) {

                if (modifiers.length > layer.modifiers.length) {

                    boundInputs = boundInputs[0..i] ~ newLayer ~ boundInputs[i..$];
                    found = true;
                    break;

                }

            }

            if (!found) boundInputs ~= newLayer;

            assert(isSorted(boundInputs));

        }

    }

    /// Bind a key stroke or button to given input action, replacing any previously bound inputs.
    void bindInputReplace(InputActionID action, InputStroke stroke)
    in (stroke.length != 0)
    do {

        import std.array;

        // Find a matching layer
        if (auto layer = layerForStroke(stroke)) {

            // Remove any stroke that matches
            layer.bindings = layer.bindings.filter!(a => a.trigger == stroke.input[$-1]).array;

            // Insert the binding
            layer.bindings ~= InputBinding(action, stroke.input[$-1]);

        }

        // Layer doesn't exist, bind it the straightforward way
        else bindInput(action, stroke);

    }

    /// List actions in the tree, remove finished actions while iterating.
    auto filterActions() {

        struct ActionIterator {

            LayoutTree* tree;

            int opApply(int delegate(TreeAction) @safe fun) {

                tree._actionAccessCounter++;
                scope (exit) tree._actionAccessCounter--;

                // Regular access
                if (tree._actionAccessCounter == 1) {

                    for (auto range = tree.actions[]; !range.empty; ) {

                        // Yield the item
                        auto result = fun(range.front);

                        // If finished, remove from the queue
                        if (range.front.toStop) tree.actions.popFirstOf(range);

                        // Continue to the next item
                        else range.popFront();

                        // Stop iteration if requested
                        if (result) return result;

                    }

                }

                // Nested access
                else {

                    for (auto range = tree.actions[]; !range.empty; ) {

                        auto front = range.front;
                        range.popFront();

                        // Ignore stopped items
                        if (front.toStop) continue;

                        // Yield the item
                        if (auto result = fun(front)) {

                            return result;

                        }

                    }

                }

                return 0;

            }

        }

        return ActionIterator(&this);

    }

    /// Intersect the given rectangle against current scissor area.
    Rectangle intersectScissors(Rectangle rect) {

        import std.algorithm : min, max;

        // No limit applied
        if (scissors is scissors.init) return rect;

        Rectangle result;

        // Intersect
        result.x = max(rect.x, scissors.x);
        result.y = max(rect.y, scissors.y);
        result.w = max(0, min(rect.x + rect.w, scissors.x + scissors.w) - result.x);
        result.h = max(0, min(rect.y + rect.h, scissors.y + scissors.h) - result.y);

        return result;

    }

    /// Start scissors mode.
    /// Returns: Previous scissors mode value. Pass that value to `popScissors`.
    Rectangle pushScissors(Rectangle rect) {

        const lastScissors = scissors;

        // Intersect with the current scissors rectangle.
        io.area = scissors = intersectScissors(rect);

        return lastScissors;

    }

    void popScissors(Rectangle lastScissorsMode) @trusted {

        // Pop the stack
        scissors = lastScissorsMode;

        // No scissors left
        if (scissors is scissors.init) {

            // Restore full draw area
            backend.restoreArea();

        }

        else {

            // Start again
            backend.area = scissors;

        }

    }

    /// Fetch tree events (e.g. actions)
    void poll() {

        // Run texture reaper
        io.reaper.check();

        // Reset all actions
        downActions.clear();
        activeActions.clear();

        // Test all bindings
        foreach (layer; boundInputs) {

            // Check if the layer is active
            if (!layer.modifiers.isDown(backend)) continue;

            // Found an active layer, test all bound strokes
            foreach (binding; layer.bindings) {

                // Register held-down actions
                if (InputStroke.isItemDown(backend, binding.trigger)) {

                    downActions ~= binding;

                }

                // Register triggered actions
                if (InputStroke.isItemActive(backend, binding.trigger)) {

                    activeActions ~= binding;

                }

            }

            // End on this layer
            break;

        }

    }

}

@("LayoutTree.isHovered is true when a node is hovered, false when not")
unittest {

    import fluid.space;
    import fluid.label;
    import fluid.structs;
    import fluid.default_theme;

    auto io = new HeadlessBackend;
    auto text = label("Hello, World!");
    auto root = vspace(
        layout!"fill",
        nullTheme,
        text
    );

    io.mousePosition = Vector2(5, 5);
    root.io = io;
    root.draw();

    assert(root.tree.hover is text);
    assert(root.tree.isHovered);

    io.nextFrame;
    io.mousePosition = Vector2(-1, -1);
    root.draw();
    
    assert(root.tree.hover !is text);
    assert(!root.tree.isHovered);

    io.nextFrame;
    io.mousePosition = Vector2(5, 50);
    root.draw();

    assert(root.tree.hover !is text);
    assert(!root.tree.isHovered);

}
