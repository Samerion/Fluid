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

/// Global data for the layout tree.
struct LayoutTree {

    import fluid.theme : Breadcrumbs;

    /// Miscelleanous, technical properties.
    public {

        /// Current rectangle drawing is limited to.
        Rectangle scissors;

        /// True if the current tree branch is marked as disabled (doesn't take input).
        bool isBranchDisabled;

    }

    /// Incremented for every `filterActions` access to prevent nested accesses from breaking previously made ranges.
    private int _actionAccessCounter;
}
