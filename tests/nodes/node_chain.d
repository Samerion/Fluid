module nodes.node_chain;

import fluid;

@safe:

alias chainLink = nodeBuilder!ChainLink;

class ChainLink : NodeChain {

    int drawChildCalls;
    int beforeResizeCalls;
    int afterResizeCalls;
    int beforeDrawCalls;
    int afterDrawCalls;

    this() {

    }

    this(Node next) {

        super(next);

    }

    override void drawChild(Node child, Rectangle space) {
        drawChildCalls++;
        super.drawChild(child, space);
    }

    override void beforeResize(Vector2) {
        beforeResizeCalls++;
        assert(beforeResizeCalls == afterResizeCalls + 1);
    }

    override void afterResize(Vector2) {
        afterResizeCalls++;
        assert(beforeResizeCalls == afterResizeCalls);
    }

    override void beforeDraw(Rectangle, Rectangle) {
        beforeDrawCalls++;
        assert(beforeDrawCalls == afterDrawCalls + 1);
    }

    override void afterDraw(Rectangle, Rectangle) {
        afterDrawCalls++;
        assert(beforeDrawCalls == afterDrawCalls);
    }

}

@("NodeChain can be empty")
unittest {

    auto link = chainLink();
    auto root = testSpace(link);
    root.drawAndAssert(
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

    auto link = chainLink(
        link1 = chainLink(
            link2 = chainLink(
                link3 = chainLink(
                    content = label("hi"),
                ),
            ),
        ),
    );
    auto root = testSpace(link);

    // Root link draws all the links, but it is not exposed through tree actions
    root.drawAndAssert(
        link.drawsChild(link1),
        link1.drawsChild(link2),
        link2.drawsChild(link3),
        link3.drawsChild(content),
    );
    assert(link.afterDrawCalls  == 1);
    assert(link1.afterDrawCalls == 1);
    assert(link2.afterDrawCalls == 1);
    assert(link3.afterDrawCalls == 1);
    assert(link.drawChildCalls  == 1);
    assert(link1.drawChildCalls == 0);
    assert(link2.drawChildCalls == 0);
    assert(link3.drawChildCalls == 0);

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
