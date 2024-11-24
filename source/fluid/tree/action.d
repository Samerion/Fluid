module fluid.tree.action;

import fluid.node;
import fluid.tree.types;

@safe:

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
