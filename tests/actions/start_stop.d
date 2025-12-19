module actions.start_stop;

import fluid;

@safe:

class StartAndStopAction : TreeAction {

    int starts;
    int stops;
    int iterations;
    bool continueAfter;

    override void started() {
        starts++;
    }

    override void stopped() {
        super.stopped();
        stops++;
    }

    override void beforeTree(Node, Rectangle) {
        assert(starts > stops);
        iterations++;
    }

    override void afterTree() {
        if (!continueAfter) {
            stop;
        }
    }

}

@("Node.startAction() will fire start and stop hooks")
unittest {

    auto root = vspace();
    auto action = new StartAndStopAction;
    root.startAction(action);

    root.draw();
    assert(action.starts == 1);
    assert(action.stops == 1);
    assert(action.iterations == 1);

    action.continueAfter = true;
    root.startAction(action);
    root.draw();
    assert(action.starts == 2);
    assert(action.stops == 1);
    assert(action.iterations == 2);

}
