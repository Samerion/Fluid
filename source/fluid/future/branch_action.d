module fluid.future.branch_action;

import fluid.node;
import fluid.tree;
import fluid.types;

@safe:

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

    /// ditto
    final override void afterInput(ref bool) { }

    /// Branch action excludes the start node from results.
    /// Returns:
    ///     True only if the node is a child of the `startNode`; always true if there isn't one set.
    override bool filterBeforeDraw(Node node) @trusted {

        _balance++;

        const filter = super.filterBeforeDraw(node);

        // Skip the start node
        if (startNode !is null && node == startNode) {
            return false;
        }

        return filter;
        

    }

    /// Branch action excludes the start node from results.
    /// Returns:
    ///     True only if the node is a child of the `startNode`; always true if there isn't one set.
    override bool filterAfterDraw(Node node) @trusted { 

        const filter = super.filterAfterDraw(node);

        _balance--;

        // Stop if balance is negative
        if (_balance < 0) {
            stop;
            return false;
        }

        // Stop the action when exiting the start node
        if (startNode !is null && node == startNode) {
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
