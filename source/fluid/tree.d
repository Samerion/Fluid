module fluid.tree;

import std.conv;
import std.math;
import std.container;
import std.algorithm;

import fluid.node;
import fluid.input;
import fluid.style;

import fluid.future.pipe;
import fluid.future.context;


@safe:


version (OSX)
    version = Fluid_MacKeyboard;

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

        /// Value `priority` is summed with on each step. `1` before finding the focused node, `-1` after.
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
    ///     box     = Box defining node boundaries (focus box)
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
abstract class TreeAction : Publisher!() {

    public {

        /// Node to descend into; `beforeDraw` and `afterDraw` will only be emitted for this node and its children.
        ///
        /// May be null to enable iteration over the entire tree.
        Node startNode;

        /// If true, this action is complete and no callbacks should be ran.
        ///
        /// Overloads of the same callbacks will still be called for the event that prompted stopping.
        bool toStop;  // this should be private

        /// Keeps track of the number of times the action has been started or stopped. Every start and every stop
        /// bumps the generation number.
        ///
        /// The generation number is used to determine if the action runner should continue or discontinue the action.
        /// If the number is greater than the one the runner stored at the time it was scheduled, it will stop running.
        /// This means that if an action is restarted, the old run will be unregistered, preventing the action from
        /// running twice at a time.
        ///
        /// Only applies to actions started using `Node.startAction`, introduced in 0.7.2, and not `Node.runAction`.
        int generation;

    }

    private {

        /// Subscriber for events, i.e. `then`
        Event!() _finished;

        /// Set to true once the action has descended into `startNode`.
        bool _inStartNode;

        /// Set to true once `beforeTree` is called. Set to `false` afterwards.
        bool _inTree;

    }

    /// Returns: True if the tree is currently drawing `startNode` or any of its children.
    bool inStartNode() const {
        return _inStartNode;
    }

    /// Returns: True if the tree has been entered. Set to true on `beforeTree` and to false on `afterTree`.
    bool inTree() const {
        return _inTree;
    }

    /// Remove all event handlers attached to this tree.
    void clearSubscribers() {
        _finished.clearSubscribers();
    }

    override final void subscribe(Subscriber!() subscriber) {
        _finished.subscribe(subscriber);
    }

    /// Stop the action.
    ///
    /// No further hooks will be triggered after calling this, and the action will soon be removed from the list
    /// of running actions. Overloads of the same hook that called `stop` may still be called.
    final void stop() {

        if (toStop) return;

        // Perform the stop
        generation++;
        toStop = true;
        stopped();

        // Reset state
        _inStartNode = false;
        _inTree      = false;

    }

    /// Called whenever this action is started — added to the list of running actions in the `LayoutTree`
    /// or `TreeContext`.
    ///
    /// This hook may not be called immediately when added through `node.queueAction` or `node.startAction`;
    /// it will wait until the node's first resize so it can connect to the tree.
    void started() {

    }

    /// Called whenever this action is stopped by calling `stop`.
    ///
    /// This can be used to trigger user-assigned callbacks. Call `super.stopped()` when overriding to make sure all
    /// finish hooks are called.
    void stopped() {
        _finished();
    }

    /// Determine whether `beforeTree` and `afterTree` should be called.
    ///
    /// By default, `afterTree` is disabled if `beforeTree` wasn't called before.
    /// Subclasses may change this to adjust this behavior.
    ///
    /// Returns:
    ///     For `filterBeforeTree`, true if `beforeTree` is to be called.
    ///     For `filterAfterTree`, true if `afterTree` is to be called.
    bool filterBeforeTree() {
        return true;
    }

    /// ditto
    bool filterAfterTree() {
        return inTree;
    }

    /// Determine whether `beforeDraw` and `afterDraw` should be called for the given node.
    ///
    /// By default, this is used to filter out all nodes except for `startNode` and its children, and to keep
    /// the action from starting in the middle of the tree.
    /// Subclasses may change this to adjust this behavior.
    ///
    /// Params:
    ///     node = Node that is subject to the hook call.
    /// Returns:
    ///     For `filterBeforeDraw`, true if `beforeDraw` is to be called for this node.
    ///     For `filterAfterDraw`, true if `afterDraw` is to be called for this node.
    bool filterBeforeDraw(Node node) {

        // Not in tree
        if (!inTree) return false;

        // Start mode must have been reached
        return startNode is null || inStartNode;

    }

    /// ditto
    bool filterAfterDraw(Node node) {

        // Not in tree
        if (!inTree) return false;

        // Start mode must have been reached
        return startNode is null || inStartNode;

    }

    /// Called before the tree is drawn. Keep in mind this might not be called if the action is started when tree
    /// iteration has already begun.
    /// Params:
    ///     root     = Root of the tree.
    ///     viewport = Screen space for the node.
    void beforeTree(Node root, Rectangle viewport) { }

    final package void beforeTreeImpl(Node root, Rectangle viewport) {

        _inTree = true;

        if (filterBeforeTree()) {
            beforeTree(root, viewport);
        }

    }

    /// Called before a node is resized.
    void beforeResize(Node node, Vector2 viewportSpace) { }

    final package void beforeResizeImpl(Node node, Vector2 viewport) {
        beforeResize(node, viewport);
    }

    /// Called after a node is resized.
    void afterResize(Node node, Vector2 viewportSpace) { }

    final package void afterResizeImpl(Node node, Vector2 viewport) {
        afterResize(node, viewport);
    }

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
    final package void beforeDrawImpl(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) {

        // Open the start branch
        if (startNode && node.opEquals(startNode)) {
            _inStartNode = true;
        }

        // Run the hooks if the filter passes
        if (filterBeforeDraw(node)) {
            beforeDraw(node, space, paddingBox, contentBox);
            beforeDraw(node, space);
        }

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
    final package void afterDrawImpl(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) {

        // Run the filter
        if (filterAfterDraw(node)) {
            afterDraw(node, space, paddingBox, contentBox);
            afterDraw(node, space);
        }

        // Close the start branch
        if (startNode && node.opEquals(startNode)) {
            _inStartNode = false;
        }

    }

    /// Called after the tree is drawn. Called before input events, so they can assume actions have completed.
    ///
    /// By default, calls `stop()` preventing the action from evaluating during next draw.
    void afterTree() {

        stop();

    }

    final package void afterTreeImpl() {

        if (filterAfterTree()) {
            afterTree();
        }
        _inTree = false;

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

        /// Context for the new I/O system. https://git.samerion.com/Samerion/Fluid/issues/148
        TreeContextData context;

    }

    /// Incremented for every `filterActions` access to prevent nested accesses from breaking previously made ranges.
    private int _actionAccessCounter;

    /// Create a new tree with the given node as its root.
    this(Node root) {
        this.root = root;
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

        // Run the first hook
        action.started();

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

                // Run new actions too
                foreach (action; tree.context.actions) {

                    if (auto result = fun(action)) {
                        return result;
                    }

                }

                return 0;

            }

        }

        return ActionIterator(&this);

    }
}
