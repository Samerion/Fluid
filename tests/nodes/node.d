module nodes.node;

import fluid;
import std.algorithm;

@safe:

@("Themes can be changed at runtime https://git.samerion.com/Samerion/Fluid/issues/114")
unittest {

    auto theme1 = nullTheme.derive(
        rule!Frame(
            Rule.backgroundColor = color("#000"),
        ),
    );
    auto theme2 = nullTheme.derive(
        rule!Frame(
            Rule.backgroundColor = color("#fff"),
        ),
    );

    auto deepFrame = vframe();
    auto blackFrame = vframe(theme1);
    auto root = vframe(
        theme1,
        vframe(
            vframe(deepFrame),
        ),
        vframe(blackFrame),
    );

    root.draw();
    assert(deepFrame.pickStyle.backgroundColor == color("#000"));
    assert(blackFrame.pickStyle.backgroundColor == color("#000"));
    root.theme = theme2;
    root.draw();
    assert(deepFrame.pickStyle.backgroundColor == color("#fff"));
    assert(blackFrame.pickStyle.backgroundColor == color("#000"));

}

@("Node.hide() can be used to prevent nodes from drawing")
unittest {

    int drawCount;

    auto root = new class Node {

        CanvasIO canvasIO;

        override void resizeImpl(Vector2) {
            require(canvasIO);
            minSize = Vector2(10, 10);
        }

        override void drawImpl(Rectangle outer, Rectangle inner) {
            drawCount++;
            canvasIO.drawRectangle(inner,
                color("#123"));
        }

    };

    auto test = testSpace(nullTheme, root);
    test.drawAndAssert(
        root.drawsRectangle(0, 0, 10, 10).ofColor("123"),
        root.doesNotDraw(),
    );
    assert(drawCount == 1);

    // Hide the node now
    root.hide();
    test.drawAndAssertFailure(
        root.draws(),
    );
    assert(drawCount == 1);

}

@("TreeAction can be attached to the tree, or to a branch")
unittest {

    import fluid.space;

    Node[4] allNodes;
    Node[] visitedNodes;

    auto action = new class TreeAction {

        override void beforeDraw(Node node, Rectangle) {
            visitedNodes ~= node;
        }

    };

    auto root = allNodes[0] = vspace(
        allNodes[1] = hspace(
            allNodes[2] = hspace(),
        ),
        allNodes[3] = hspace(),
    );

    // Start the action before creating the tree
    root.startAction(action);
    root.draw();
    assert(visitedNodes == allNodes);

    // Start an action in a branch
    visitedNodes = [];
    allNodes[1].startAction(action);
    root.draw();

    // @system on LDC 1.28
    () @trusted {
        assert(visitedNodes[].equal(allNodes[1..3]));
    }();

}

@("Resizes only happen once after updateSize()")
unittest {

    int resizes;

    auto root = new class Node {

        override void resizeImpl(Vector2) {
            resizes++;
        }
        override void drawImpl(Rectangle, Rectangle) { }

    };
    auto test = testSpace(nullTheme, root);

    assert(resizes == 0);

    // Resizes are only done on request
    foreach (i; 0..10) {
        test.draw();
        assert(resizes == 1);
    }

    // Perform such a request
    root.updateSize();
    assert(resizes == 1);

    // Resize will be done right before next draw
    test.draw();
    assert(resizes == 2);

    // No unnecessary resizes if multiple things change in a single branch
    root.updateSize();
    root.updateSize();

    test.draw();
    assert(resizes == 3);

    // Another draw, no more resizes
    test.draw();
    assert(resizes == 3);

}

@("NodeAlign changes how a node is placed in its available box")
unittest {

    import std.exception;
    import core.exception;
    import fluid.frame;

    static class Square : Frame {

        CanvasIO canvasIO;
        Color color;

        this(Color color) @safe {
            this.color = color;
        }

        override void resizeImpl(Vector2) {
            require(canvasIO);
            minSize = Vector2(100, 100);
        }

        override void drawImpl(Rectangle, Rectangle inner) {
            canvasIO.drawRectangle(inner, color);
        }

    }

    alias square = nodeBuilder!Square;

    auto colors = [
        color("7ff0a5"),
        color("17cccc"),
        color("a6a415"),
        color("cd24cf"),
    ];
    auto theme = nullTheme.derive(
        rule!Frame(Rule.backgroundColor = color("1c1c1c"))
    );
    auto squares = [
        square(.layout!"start",  colors[0]),
        square(.layout!"center", colors[1]),
        square(.layout!"end",    colors[2]),
        square(.layout!"fill",   colors[3]),
    ];
    auto root = vframe(
        .layout!(1, "fill"),
        squares,
    );
    auto test = testSpace(
        .layout!"fill",
        theme,
        root
    );

    // Each square is placed in order
    test.drawAndAssert(
        squares[0].drawsRectangle(  0,   0, 100, 100).ofColor(colors[0]),
        squares[1].drawsRectangle(350, 100, 100, 100).ofColor(colors[1]),
        squares[2].drawsRectangle(700, 200, 100, 100).ofColor(colors[2]),

        // Except the last one, which is turned into a rectangle by "fill"
        // A proper rectangle class would change its target rectangles to keep aspect ratio
        squares[3].drawsRectangle(  0, 300, 800, 100).ofColor(colors[3]),
    );

    // Now do the same, but expand each node
    foreach (child; root.children) {
        child.layout.expand = 1;
    }
    test.drawAndAssertFailure();  // Oops, forgot to resize!

    // Update the size
    root.updateSize;
    test.drawAndAssert(
        squares[0].drawsRectangle(  0,   0, 100, 100).ofColor(colors[0]),
        squares[1].drawsRectangle(350, 175, 100, 100).ofColor(colors[1]),
        squares[2].drawsRectangle(700, 350, 100, 100).ofColor(colors[2]),
        squares[3].drawsRectangle(  0, 450, 800, 150).ofColor(colors[3]),
    );

    // Change Y alignment
    root.children[0].layout = .layout!(1, "start", "end");
    root.children[1].layout = .layout!(1, "center", "fill");
    root.children[2].layout = .layout!(1, "end", "start");
    root.children[3].layout = .layout!(1, "fill", "center");

    root.updateSize;
    test.drawAndAssert(
        squares[0].drawsRectangle(  0,  50, 100, 100).ofColor(colors[0]),
        squares[1].drawsRectangle(350, 150, 100, 150).ofColor(colors[1]),
        squares[2].drawsRectangle(700, 300, 100, 100).ofColor(colors[2]),
        squares[3].drawsRectangle(  0, 475, 800, 100).ofColor(colors[3]),
    );

    // Try different expand values
    root.children[0].layout = .layout!(0, "center", "fill");
    root.children[1].layout = .layout!(1, "center", "fill");
    root.children[2].layout = .layout!(2, "center", "fill");
    root.children[3].layout = .layout!(3, "center", "fill");

    root.updateSize;
    test.drawAndAssert(
        // The first rectangle doesn't expand so it should be exactly 100×100 in size
        squares[0].drawsRectangle(350,   0, 100, 100).ofColor(colors[0]),

        // The remaining space is 500px, so divided into 1+2+3=6 pieces, it should be about 83.33px per piece
        squares[1].drawsRectangle(350, 100.00, 100,  83.33).ofColor(colors[1]),
        squares[2].drawsRectangle(350, 183.33, 100, 166.66).ofColor(colors[2]),
        squares[3].drawsRectangle(350, 350.00, 100, 250.00).ofColor(colors[3]),
    );

}

@("Node.configure() changes tree wrapper in use")
unittest {
    import fluid.label;
    import fluid.future.context;

    class BlankNode : Node {
        override void resizeImpl(Vector2) { }
        override void drawImpl(Rectangle, Rectangle) { }
    }

    auto root = new BlankNode;
    TreeWrapper activeWrapper;

    class Wrapper : TreeWrapper {

        override void drawTree(TreeContext, Node) {
            activeWrapper = this;
        }

        override void runTree(TreeContext, Node) {
            activeWrapper = this;
        }

    }

    auto wrapper1 = new Wrapper;
    auto wrapper2 = new Wrapper;

    root.configure(wrapper1);
    root.draw();
    assert(activeWrapper is wrapper1);
    assert(root.treeContext.wrapper is activeWrapper);

    root.configure(wrapper2);
    root.draw();
    assert(activeWrapper is wrapper2);
    assert(root.treeContext.wrapper is activeWrapper);

    root.configureBlank();
    root.draw();
    assert(root.treeContext.wrapper is null);
}
