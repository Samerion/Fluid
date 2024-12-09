module fluid.future.branch_action;

import fluid.node;
import fluid.tree;
import fluid.types;

@safe:

abstract class BranchAction : TreeAction {

    /// A branch action can only hook to draw calls of specific nodes. It cannot bind into these hooks.
    final override void beforeTree(Node, Rectangle) { }

    /// ditto
    final override void beforeResize(Node, Vector2) { }

    /// ditto
    final override void afterTree() { }

    /// ditto
    final override void afterInput(ref bool) { }

}
