module actions.scheduling;

import fluid;

@safe:

class CountNodesAction : TreeAction {

    int runs;
    int nodesDrawn;

    override void beforeTree(Node, Rectangle) {
        runs++;
        nodesDrawn = 0;
    }

    override void beforeDraw(Node, Rectangle) {
        nodesDrawn++;
    }

}

@("Actions can be scheduled using the new system")
unittest {

    auto root = vspace(
        vspace(),
        vspace(),
    );
    auto action = new CountNodesAction;

    root.runAction(action);
    root.draw();
    assert(action.nodesDrawn == 3);

}

@("TreeAction.stop will stop the action from running")
unittest {

    auto action = new CountNodesAction;
    auto root = vspace();

    root.runAction(action);
    root.draw();
    assert(action.runs == 1);
    root.draw();
    assert(action.runs == 1);

}

@("TreeActions are reusable")
unittest {

    auto action = new CountNodesAction;
    auto root = vspace();

    root.runAction(action);
    root.draw();
    assert(action.runs == 1);

    root.runAction(action);
    root.draw();
    assert(action.runs == 2);

    root.runAction(action);
    root.draw();
    assert(action.runs == 3);

}
