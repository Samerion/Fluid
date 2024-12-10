module actions.tree_action;

import fluid;

@safe:

class OnlyRunsOnce : TreeAction {

    bool treeReached;

    void reset() {
        treeReached = false;
    }

    override void beforeTree(Node, Rectangle) {
        assert(!treeReached, "beforeTree ran twice");
        treeReached = true;
    }

}

@("Starting an action removes previous runs")
unittest {

    auto root = vspace();
    auto action = new OnlyRunsOnce;

    // Regular run
    assert(!action.treeReached);
    root.startAction(action);
    root.draw();
    assert(action.treeReached);

    // Scheduled multiple times
    action.reset();
    root.startAction(action);
    root.startAction(action);
    root.startAction(action);
    root.draw();
    assert(action.treeReached);

    root.draw();

}
