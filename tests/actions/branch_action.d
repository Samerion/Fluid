module actions.branch_action;

import fluid;
import fluid.future.branch_action;

@safe:

class NodeCountAction : BranchAction {

    int nodeCount;
    int starts;
    int stops;

    override void started() {
        nodeCount = 0;
        starts++;
    }

    override void beforeDraw(Node, Rectangle) {
        nodeCount++;
        assert(starts > stops);
    }

    override void stopped() {
        stops++;
        assert(stops == starts);
    }

}

class NodeCounter : Space {

    NodeCountAction nodeCountAction;

    this(Node[] nodes...) {
        super(nodes);
        nodeCountAction = new NodeCountAction;
    }

    int nodeCount() const {
        return nodeCountAction.nodeCount;
    }

    int runs() const {
        return nodeCountAction.stops;
    }

    override void drawImpl(Rectangle outer, Rectangle inner) {
        const originalRuns = runs;
        assert(nodeCountAction.starts == nodeCountAction.stops);
        {
            auto frame = startBranchAction(nodeCountAction);
            assert(nodeCountAction.starts == nodeCountAction.stops + 1);
            super.drawImpl(outer, inner);
        }
        assert(nodeCountAction.starts == nodeCountAction.stops);
        assert(runs == originalRuns + 1);
    }

}

alias nodeCounter = nodeBuilder!NodeCounter;

@("startBranchAction launches a scope-bound action when drawn")
unittest {

    auto counter = nodeCounter(
        vspace(
            hspace(),
        ),
        hspace(),
    );
    auto root = vspace(
        counter,
        vspace()
    );
    assert(counter.nodeCount == 0);
    assert(counter.runs == 0);

    root.draw();
    assert(counter.nodeCount == 3);
    assert(counter.runs == 1);

    root.draw();
    assert(counter.runs == 2);

    counter.hide();
    root.draw();
    assert(counter.runs == 2);

    counter.show();
    root.draw();
    assert(counter.runs == 3);

}
