module fluid.tree;

import std.conv;
import std.math;
import std.container;
import std.algorithm;

import fluid.node;
import fluid.input;
import fluid.style;
import fluid.backend;


@safe:


///
struct FocusDirection {

    struct WithPriority {

        /// Pick priority based on tree distance from the focused node.
        int priority;

        /// Square of the distance between this node and the focused node.
        float distance2;

        /// The node.
        FluidFocusable node;

        alias node this;

    }

    /// Available space box of the focused item after last frame.
    Rectangle lastFocusBox;

    /// Nodes that may get focus with tab navigation.
    FluidFocusable previous, next;

    /// First and last focusable nodes in the tree.
    FluidFocusable first, last;

    /// Focusable nodes, by direction from the focused node.
    WithPriority[4] positional;

    /// Focus priority for the currently drawn node.
    ///
    /// Increased until the focused node is found, decremented afterwards. As a result, values will be the highest for
    /// nodes near the focused one. Changes with tree depth rather than individual nodes.
    int priority;

    private {

        /// Value `prioerity` is summed with on each step. `1` before finding the focused node, `-1` after.
        int priorityDirection = 1;

        /// Current tree depth.
        uint depth;

    }

    /// Update focus info with the given node. Automatically called when a node is drawn, shouldn't be called manually.
    ///
    /// `previous` will be the last focusable node encountered before the focused node, and `next` will be the first one
    /// after. `first` and `last will be the last focusable nodes in the entire tree.
    ///
    /// Params:
    ///     current = Node to update the focus info with.
    ///     box     = Box defining node boundaries (padding box)
    ///     depth   = Current tree depth. Pass in `tree.depth`.
    void update(Node current, Rectangle box, uint depth)
    in (current !is null, "Current node must not be null")
    do {

        import std.algorithm : either;

        auto currentFocusable = cast(FluidFocusable) current;

        // Count focus priority
        {

            // Get depth difference since last time
            const int depthDiff = depth - this.depth;

            // Count steps in change of depth
            priority += priorityDirection * abs(depthDiff);

            // Update depth
            this.depth = depth;

        }

        // Stop if the current node can't take focus
        if (!currentFocusable) return;

        // And it DOES have focus
        if (current.tree.focus is currentFocusable) {

            // Mark the node preceding it to the last encountered focusable node
            previous = last;

            // Clear the next node, so it can be overwritten by a correct value.
            next = null;

            // Reverse priority target
            priorityDirection = -1;

        }

        else {

            // Update positional focus
            updatePositional(currentFocusable, box);

            // There's no node to take focus next, set it now
            if (next is null) next = currentFocusable;

        }


        // Set the current node as the first focusable, if true
        if (first is null) first = currentFocusable;

        // Replace the last
        last = currentFocusable;

    }

    /// Check the given node's position and update `positional` to match.
    private void updatePositional(FluidFocusable node, Rectangle box) {

        // Note: This might give false-positives if the focused node has changed during this frame

        // Check each direction
        foreach (i, ref otherNode; positional) {

            const side = cast(Style.Side) i;
            const dist = distance2(box, side);

            // If a node took this spot before
            if (otherNode !is null) {

                // Ignore if the other node has higher priority
                if (otherNode.priority > priority) continue;

                // If priorities are equal, check if we're closer than the other node
                if (otherNode.priority == priority
                    && otherNode.distance2 < dist) continue;

            }

            // Check if this node matches the direction
            if (checkDirection(box, side)) {

                // Replace the node
                otherNode = WithPriority(priority, dist, node);

            }

        }

    }

    /// Check if the given box is located to the given side of the focus box.
    bool checkDirection(Rectangle box, Style.Side side) {

        // Distance between box sides facing each other.
        //
        // ↓ lastFocusBox  ↓ box
        // +======+        +------+
        // |      |        |      |
        // |      | ~~~~~~ |      |
        // |      |        |      |
        // +======+        +------+
        //   side ↑        ↑ side.reverse
        const distanceExternal = lastFocusBox.getSide(side) - box.getSide(side.reverse);

        // Distance between corresponding box sides.
        //
        // ↓ lastFocusBox  ↓ box
        // +======+        +------+
        // |      |        :      |
        // |      | ~~~~~~~~~~~~~ |
        // |      |        :      |
        // +======+        +------+
        //   side ↑          side ↑
        const distanceInternal = lastFocusBox.getSide(side) - box.getSide(side);

        // The condition for the return value to be true, is for distanceInternal to be greater than distanceExternal.
        // This is not the case in the opposite situation.
        //
        // For example, if we're checking if the box is on the *right* of lastFocusBox:
        //
        // trueish scenario:                                 falseish scenario:
        // Box is to the right of lastFocusBox               Box is the left of lastFocusBox
        //
        // ↓ lastFocusBox  ↓ box                             ↓ box           ↓ lastFocusBox
        // +======+        +------+                          +------+        +======+
        // |      | ~~~~~~ :      | external                 | ~~~~~~~~~~~~~~~~~~~~ | external
        // |      |        :      |    <                     |      :        :      |    >
        // |      | ~~~~~~~~~~~~~ | internal                 |      : ~~~~~~~~~~~~~ | internal
        // +======+        +------+                          +------+        +======+
        //   side ↑        ↑ side.reverse                      side ↑          side ↑
        const condition = abs(distanceInternal) > abs(distanceExternal);

        // ↓ box                    There is an edgecase though. If one box entirely overlaps the other on one axis, we
        // +--------------------+   might end up with unwanted behavior, for example, in a ScrollFrame, focus might
        // |   ↓ lastFocusBox   |   switch to the scrollbar instead of a child, as we would normally expect.
        // |   +============+   |
        // |   |            |   |   For this reason, we require both `distanceInternal` and `distanceExternal` to have
        // +---|            |---+   the same sign, as it normally would, but not here.
        //     |            |
        //     +============+       One can still navigate to the `box` using controls for the other axis.
        return condition
            && distanceInternal * distanceExternal >= 0;

    }

    /// Get the square of the distance between given box and `lastFocusBox`.
    float distance2(Rectangle box, Style.Side side) {

        /// Get the center of given rectangle on the axis opposite to the results of getSide.
        float center(Rectangle rect) {

            return side == Style.Side.left || side == Style.Side.right
                ? rect.y + rect.height
                : rect.x + rect.width;

        }

        // Distance between box sides facing each other, see `checkDirection`
        const distanceExternal = lastFocusBox.getSide(side) - box.getSide(side.reverse);

        /// Distance between centers of the boxes on the other axis
        const distanceOpposite = center(box) - center(lastFocusBox);

        return distanceExternal^^2 + distanceOpposite^^2;

    }

}

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

    /// Called before the tree is resized. Called before `beforeTree`.
    void beforeResize(Node root, Vector2 viewportSpace) { }

    /// Called before the tree is drawn. Keep in mind this might not be called if the action is started when tree
    /// iteration has already begun.
    /// Params:
    ///     root     = Root of the tree.
    ///     viewport = Screen space for the node.
    void beforeTree(Node root, Rectangle viewport) { }

    /// Called before each `drawImpl` call of any node in the tree, so supplying parent nodes before their children.
    /// Params:
    ///     node       = Node that's about to be drawn.
    ///     space      = Space given for the node.
    ///     paddingBox = Padding box of the node.
    ///     contentBox = Content box of teh node.
    void beforeDraw(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) { }

    /// ditto
    void beforeDraw(Node node, Rectangle space) { }

    /// internal
    final package void beforeDrawImpl(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) {

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
    /// Params:
    ///     node       = Node that's about to be drawn.
    ///     space      = Space given for the node.
    ///     paddingBox = Padding box of the node.
    ///     contentBox = Content box of teh node.
    void afterDraw(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) { }

    /// ditto
    void afterDraw(Node node, Rectangle space) { }

    /// internal
    final package void afterDrawImpl(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) {

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

    /// Root node of the tree.
    Node root;

    /// Top-most hovered node in the tree.
    Node hover;

    /// Currently focused node.
    ///
    /// Changing this value directly is discouraged. Some nodes might not want the focus! Be gentle, call
    /// `FluidFocusable.focus()` instead and let the node set the value on its own.
    FluidFocusable focus;

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

    /// Check if keyboard input was handled; updated after rendering has completed.
    bool keyboardHandled;

    /// Current node drawing depth.
    uint depth;

    /// Current rectangle drawing is limited to.
    Rectangle scissors;

    /// True if the current tree branch is marked as disabled (doesn't take input).
    bool isBranchDisabled;

    package uint _disabledDepth;

    /// Incremented for every `filterActions` access to prevent nested accesses from breaking previously made ranges.
    private int _actionAccessCounter;

    /// Current depth of "disabled" nodes, incremented for any node descended into, while any of the ancestors is
    /// disabled.
    deprecated("To be removed in 0.7.0. Use boolean `isBranchDisabled` instead. For iteration depth, check out `depth`")
    @property
    ref inout(uint) disabledDepth() inout return { return _disabledDepth; }

    /// Create a new tree with the given node as its root, and using the given backend for I/O.
    this(Node root, FluidBackend backend) {

        this.root = root;
        this.backend = backend;
        this.restoreDefaultInputBinds();

    }

    /// Create a new tree with the given node as its root. Use the default backend, if any is present.
    this(Node root) {

        assert(defaultFluidBackend, "Cannot create LayoutTree; no backend was chosen, and no default is set.");

        this(root, defaultFluidBackend);

    }

    /// Returns true if this branch requested a resize or is pending a resize.
    bool resizePending() const {

        return root.resizePending;

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

            return InputBinding(InputAction!a.id, InputStroke.Item(arg));

        }

        // TODO universal left/right key
        with (FluidInputAction)
        boundInputs = [

            InputLayer(
                InputStroke(KeyboardKey.leftControl),
                [
                    bind!backspaceWord(KeyboardKey.backspace),
                    bind!backspaceWord(KeyboardKey.w),  // emacs & vim
                    bind!entryPrevious(KeyboardKey.k),  // vim
                    bind!entryPrevious(KeyboardKey.p),  // emacs
                    bind!entryNext(KeyboardKey.j),  // vim
                    bind!entryNext(KeyboardKey.n),  // emacs
                ]
            ),

            InputLayer(
                InputStroke(KeyboardKey.leftShift),
                [
                    bind!focusPrevious(KeyboardKey.tab),
                    bind!entryPrevious(KeyboardKey.tab),
                ]
            ),

            InputLayer(
                InputStroke(KeyboardKey.leftAlt),
                [
                    bind!entryUp(KeyboardKey.up),
                ]
            ),

            InputLayer(
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
                    bind!entryPrevious(KeyboardKey.up),
                    bind!entryPrevious(GamepadButton.dpadUp),
                    bind!entryNext(KeyboardKey.down),
                    bind!entryNext(KeyboardKey.tab),
                    bind!entryNext(GamepadButton.dpadDown),

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
            )

        ];

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
    package void poll() {

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
