module fluid.tree;

import std.conv;
import std.math;
import std.container;
import std.algorithm;

import fluid.node;
import fluid.input;
import fluid.style;

import fluid.future.pipe;


@safe:


version (OSX)
    version = Fluid_MacKeyboard;

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

}

abstract class BranchAction : TreeAction {

    private {

        /// Balance is incremented when entering a node, and decremented when leaving.
        /// If the balance is negative, the action stops.
        int _balance;

    }

    /// A branch action can only hook to draw calls of specific nodes. It cannot bind into these hooks.
    final override void beforeTree(Node, Rectangle) { }

    /// ditto
    final override void beforeResize(Node, Vector2) { }

    /// ditto
    final override void afterTree() {
        stop;
    }

    /// Branch action excludes the start node from results.
    /// Returns:
    ///     True only if the node is a child of the `startNode`; always true if there isn't one set.
    override bool filterBeforeDraw(Node node) @trusted {

        _balance++;

        // No start node
        if (startNode is null) {
            return true;
        }

        const filter = super.filterBeforeDraw(node);

        // Skip the start node
        if (node == startNode) {
            return false;
        }

        return filter;


    }

    /// Branch action excludes the start node from results.
    /// Returns:
    ///     True only if the node is a child of the `startNode`; always true if there isn't one set.
    override bool filterAfterDraw(Node node) @trusted {

        _balance--;

        // Stop if balance is negative
        if (_balance < 0) {
            stop;
            return false;
        }

        // No start node
        if (startNode is null) {
            return true;
        }

        const filter = super.filterAfterDraw(node);

        // Stop the action when exiting the start node
        if (node == startNode) {
            stop;
            return false;
        }

        return filter;

    }

    override void stopped() {

        super.stopped();
        _balance = 0;

    }

}

/// Keeps track of currently active actions.
struct TreeActionContext {

    import std.array;

    private {

        struct RunningAction {

            TreeAction action;
            int generation;

            bool isStopped() const {
                return action.generation > generation;
            }

        }

        /// Currently running actions.
        Appender!(RunningAction[]) _actions;

        /// Number of running iterators. Removing tree actions will only happen if there is exactly one
        /// running iterator, as to not break the other ones.
        ///
        /// Multiple iterators may run in case a tree action draws nodes on its own: one iterator triggers
        /// the action, and the drawn node activates another iterator.
        int _runningIterators;

    }

    /// Start a number of tree actions. As the node tree is drawn, the action's hook will be called whenever
    /// a relevant place is reached in the tree.
    ///
    /// To stop a running action, call the action's `stop` method. Most tree actions will do it automatically
    /// as soon as their job is finished.
    ///
    /// If the action is already running, the previous run will be aborted. The action can only run once at a time.
    ///
    /// Params:
    ///     actions = Actions to spawn.
    void spawn(TreeAction[] actions...) {

        _actions.reserve(_actions[].length + actions.length);

        // Start every action and run the hook
        foreach (action; actions) {

            _actions ~= RunningAction(action, ++action.generation);
            action.started();


        }

    }

    /// List all currently active actions in a loop.
    int opApply(int delegate(TreeAction) @safe yield) {

        // Update the iterator counter
        _runningIterators++;
        scope (exit) _runningIterators--;

        bool kept;

        // Iterate on active actions
        // Do *not* increment if an action was removed
        for (size_t i = 0; i < _actions[].length; i += kept) {

            auto action = _actions[][i];
            kept = true;

            // If there's one running iterator, remove it from the array
            // Don't pass stopped actions to the iterator
            if (action.isStopped) {

                if (_runningIterators == 1) {
                    _actions[][i] = _actions[][$-1];
                    _actions.shrinkTo(_actions[].length - 1);
                    kept = false;
                }
                continue;

            }

            // Run the hook
            if (auto result = yield(action.action)) return result;

        }

        return 0;

    }

}
