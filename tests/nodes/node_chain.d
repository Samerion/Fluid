module nodes.node_chain;

import fluid;

@safe:

alias chainLink = nodeBuilder!ChainLink;

class ChainLink : NodeChain {

    DebugSignalIO debugSignalIO;

    int drawChildCalls;
    int beforeResizeCalls;
    int afterResizeCalls;
    int beforeDrawCalls;
    int afterDrawCalls;

    this(Node next = null) {
        super(next);
    }

    override void drawChild(Node child, Rectangle space) {
        drawChildCalls++;
        super.drawChild(child, space);
    }

    override void beforeResize(Vector2) {
        require(debugSignalIO);
        debugSignalIO.emitSignal("beforeResize");
        beforeResizeCalls++;
        assert(beforeResizeCalls == afterResizeCalls + 1);
    }

    override void afterResize(Vector2) {
        debugSignalIO.emitSignal("afterResize");
        afterResizeCalls++;
        assert(beforeResizeCalls == afterResizeCalls);
    }

    override void beforeDraw(Rectangle, Rectangle) {
        debugSignalIO.emitSignal("beforeDraw");
        beforeDrawCalls++;
        assert(beforeDrawCalls == afterDrawCalls + 1);
    }

    override void afterDraw(Rectangle, Rectangle) {
        debugSignalIO.emitSignal("afterDraw");
        afterDrawCalls++;
        assert(beforeDrawCalls == afterDrawCalls);
    }

}

@("NodeChain can be empty")
unittest {

    auto link = chainLink();
    auto root = testSpace(link);
    root.drawAndAssert(
        link.emits("beforeResize"),
        link.emits("afterResize"),
        link.emits("beforeDraw"),
        link.emits("afterDraw"),
        link.doesNotDraw,
    );
    assert(link.afterResizeCalls == 1);
    assert(link.afterDrawCalls == 1);

}

@("Node chain can contain other nodes")
unittest {

    auto content = label("Child");
    auto link = chainLink(content);
    auto root = testSpace(link);
    root.drawAndAssert(
        link.drawsChild(content),
        content.drawsImage(),
    );
    assert(link.afterResizeCalls == 1);
    assert(link.afterDrawCalls == 1);

}

@("Chain nodes can be linked")
unittest {

    Label content;
    ChainLink link1, link2, link3;

    auto link = chainLink(.layout!0,
        link1 = chainLink(.layout!1,
            link2 = chainLink(.layout!2,
                link3 = chainLink(.layout!3,
                    content = label("hi"),
                ),
            ),
        ),
    );
    auto root = testSpace(link);

    // Root link draws all the links, but it is not exposed through tree actions
    root.drawAndAssert(

        // Resize
        link1.emits("beforeResize"),
        link2.emits("beforeResize"),
        link3.emits("beforeResize"),
        link3.emits("afterResize"),
        link2.emits("afterResize"),
        link1.emits("afterResize"),

        // Draw
        link.emits("beforeDraw"),
        link.drawsChild(link1),
        link1.emits("beforeDraw"),
        link1.drawsChild(link2),
        link2.emits("beforeDraw"),
        link2.drawsChild(link3),
        link3.emits("beforeDraw"),
        link3.drawsChild(content),
        link3.emits("afterDraw"),
        link2.emits("afterDraw"),
        link1.emits("afterDraw"),
    );
    assert(link3.afterResizeCalls == 1);
    assert(link.afterDrawCalls  == 1);
    assert(link1.afterDrawCalls == 1);
    assert(link2.afterDrawCalls == 1);
    assert(link3.afterDrawCalls == 1);

    assert(link.drawChildCalls  == 0);
    assert(link1.drawChildCalls == 0);
    assert(link2.drawChildCalls == 0);
    assert(link3.drawChildCalls == 1);

}

@("chain() can be used as a prettier alternative to the constructor")
unittest {

    Label content;
    ChainLink link1, link2, link3;

    NodeChain link = chain(
        link1 = chainLink(),
        link2 = chainLink(),
        link3 = chainLink(),
        content = label("hi"),
    );
    auto root = testSpace(link);

    assert(link.opEquals(link1));

    root.drawAndAssert(
        link1.drawsChild(link2),
        link2.drawsChild(link3),
        link3.drawsChild(content),
    );

}

@("chain() returns a node if not given a chain")
unittest {

    Node node = chain(
        label("Foo")
    );
    assert(node);

}
