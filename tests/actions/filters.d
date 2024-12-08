module actions.filters;

import fluid;

@safe:

class NoBeforeDraw : TreeAction {

    int afterDrawCalled;

    override bool filterBeforeDraw(Node node) {
        super.filterBeforeDraw(node);
        return false;
    }

    override void beforeTree(Node, Rectangle) {
        afterDrawCalled = 0;
    }

    override void beforeDraw(Node, Rectangle) {
        assert(false);
    }

    override void afterDraw(Node, Rectangle) {
        afterDrawCalled++;
    }
    
}

class NoAfterDraw : TreeAction {

    int beforeDrawCalled;

    override bool filterAfterDraw(Node node) {
        super.filterAfterDraw(node);
        return false;
    }

    override void beforeTree(Node, Rectangle) {
        beforeDrawCalled = 0;
    }

    override void beforeDraw(Node, Rectangle) {
        beforeDrawCalled++;
    }

    override void afterDraw(Node, Rectangle) {
        assert(false);
    }
    
}

@("`filterBeforeDraw` can be used to control when beforeDraw() is called")
unittest {

    auto subject = vspace();
    auto root = vspace(subject);
    auto action = new NoBeforeDraw;

    root.startAction(action);
    root.draw();

    assert(action.afterDrawCalled == 2);

    subject.startAction(action);
    root.draw();

    assert(action.afterDrawCalled == 1);

}

@("`filterAfterDraw` can be used to control when afterDraw() is called")
unittest {

    auto subject = vspace();
    auto root = vspace(subject);
    auto action = new NoAfterDraw;

    root.startAction(action);
    root.draw();

    assert(action.beforeDrawCalled == 2);

    subject.startAction(action);
    root.draw();

    assert(action.beforeDrawCalled == 1);

}
