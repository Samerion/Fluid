@Migrated
module legacy.node;

import fluid;
import legacy;
import std.algorithm;

@safe:


@("Node.hide() can be used to prevent nodes from drawing")
@Migrated
unittest {

    auto io = new HeadlessBackend;
    auto root = new class Node {

        override void resizeImpl(Vector2) {
            minSize = Vector2(10, 10);
        }

        override void drawImpl(Rectangle outer, Rectangle inner) {
            io.drawRectangle(inner, color!"123");
        }

    };

    root.io = io;
    root.theme = nullTheme;
    root.draw();

    io.assertRectangle(Rectangle(0, 0, 10, 10), color!"123");
    io.nextFrame;

    // Hide the node now
    root.hide();
    root.draw();

    assert(io.rectangles.empty);

}

@("Disabled nodes cannot be interacted with. Disabled is transitive.")
@Migrated
unittest {

    import fluid.space;
    import fluid.button;
    import fluid.text_input;

    int submitted;

    auto io = new HeadlessBackend;
    auto button = fluid.button.button("Hello!", delegate { submitted++; });
    auto input = fluid.textInput("Placeholder", delegate { submitted++; });
    auto root = vspace(button, input);

    root.io = io;
    root.draw();

    // Press the button
    {
        io.nextFrame;
        io.press(KeyboardKey.enter);
        button.focus();
        root.draw();

        assert(submitted == 1);
    }

    // Press the button while disabled
    {
        io.nextFrame;
        io.press(KeyboardKey.enter);
        button.disable();
        root.draw();

        assert(button.isDisabled);
        assert(submitted == 1, "Button shouldn't trigger again");
    }

    // Enable the button and hit it again
    {
        io.nextFrame;
        io.press(KeyboardKey.enter);
        button.enable();
        root.draw();

        assert(!button.isDisabledInherited);
        assert(submitted == 2);
    }

    // Try typing into the input box
    {
        io.nextFrame;
        io.release(KeyboardKey.enter);
        io.inputCharacter("Hello, ");
        input.focus();
        root.draw();

        assert(input.value == "Hello, ");
    }

    // Disable the box and try typing again
    {
        io.nextFrame;
        io.inputCharacter("World!");
        input.disable();
        root.draw();

        assert(input.value == "Hello, ", "Input should remain unchanged");
    }

    // Attempt disabling the nodes recursively
    {
        io.nextFrame;
        io.press(KeyboardKey.enter);
        button.focus();
        input.enable();
        root.disable();
        root.draw();

        assert(root.isDisabled);
        assert(!button.isDisabled);
        assert(!input.isDisabled);
        assert(button.isDisabledInherited);
        assert(input.isDisabledInherited);
        assert(submitted == 2);
    }

    // Check the input box
    {
        io.nextFrame;
        io.press(KeyboardKey.enter);
        io.inputCharacter("World!");
        input.focus();

        root.draw();

        assert(submitted == 2);
        assert(input.value == "Hello, ");
    }

    // Enable input once again
    {
        io.nextFrame;
        io.press(KeyboardKey.enter);
        root.enable();
        root.draw();

        assert(submitted == 3);
        assert(input.value == "Hello, ");
    }

}

@("TreeAction can be attached to the tree, or to a branch")
@Migrated
unittest {

    import fluid.space;

    Node[4] allNodes;
    Node[] visitedNodes;

    auto io = new HeadlessBackend;
    auto root = allNodes[0] = vspace(
        allNodes[1] = hspace(
            allNodes[2] = hspace(),
        ),
        allNodes[3] = hspace(),
    );
    auto action = new class TreeAction {

        override void beforeDraw(Node node, Rectangle) {

            visitedNodes ~= node;

        }

    };

    // Queue the action before creating the tree
    root.queueAction(action);

    // Assign the backend; note this would create a tree
    root.io = io;

    root.draw();

    assert(visitedNodes == allNodes);

    // Clear visited nodes
    io.nextFrame;
    visitedNodes = [];
    action.toStop = false;

    // Queue an action in a branch
    allNodes[1].queueAction(action);

    root.draw();

    // @system on LDC 1.28
    () @trusted {
        assert(visitedNodes[].equal(allNodes[1..3]));
    }();

}

@("Resizes only happen once after updateSize()")
@Migrated
unittest {

    int resizes;

    auto io = new HeadlessBackend;
    auto root = new class Node {

        override void resizeImpl(Vector2) {

            resizes++;

        }
        override void drawImpl(Rectangle, Rectangle) { }

    };

    root.io = io;
    assert(resizes == 0);

    // Resizes are only done on request
    foreach (i; 0..10) {

        root.draw();
        assert(resizes == 1);
        io.nextFrame;

    }

    // Perform such a request
    root.updateSize();
    assert(resizes == 1);

    // Resize will be done right before next draw
    root.draw();
    assert(resizes == 2);
    io.nextFrame;

    // This prevents unnecessary resizes if multiple things change in a single branch
    root.updateSize();
    root.updateSize();

    root.draw();
    assert(resizes == 3);
    io.nextFrame;

    // Another draw, no more resizes
    root.draw();
    assert(resizes == 3);

}

@("Pressing tab chooses focus automatically if no focus is set")
@Abandoned
unittest {

    import fluid.space;
    import fluid.button;

    auto io = new HeadlessBackend;
    auto root = vspace(
        button("1", delegate { }),
        button("2", delegate { }),
        button("3", delegate { }),
    );

    root.io = io;

    root.draw();

    assert(root.tree.focus is null);

    // Autofocus first
    {

        io.nextFrame;
        io.press(KeyboardKey.tab);
        root.draw();

        // Fluid will automatically try to find the first focusable node
        assert(root.tree.focus.asNode is root.children[0]);

        io.nextFrame;
        io.release(KeyboardKey.tab);
        root.draw();

        assert(root.tree.focus.asNode is root.children[0]);

    }

    // Tab into the next node
    {

        io.nextFrame;
        io.press(KeyboardKey.tab);
        root.draw();
        io.release(KeyboardKey.tab);

        assert(root.tree.focus.asNode is root.children[1]);

    }

    // Autofocus last
    {
        root.tree.focus = null;

        io.nextFrame;
        io.press(KeyboardKey.leftShift);
        io.press(KeyboardKey.tab);
        root.draw();

        // If left-shift tab is pressed, the last focusable node will be used
        assert(root.tree.focus.asNode is root.children[$-1]);

        io.nextFrame;
        io.release(KeyboardKey.leftShift);
        io.release(KeyboardKey.tab);
        root.draw();

        assert(root.tree.focus.asNode is root.children[$-1]);

    }

}

@("Legacy: NodeAlign changes how a node is placed in its available box")
@system  // catching Error
@Migrated
unittest {

    import std.exception;
    import core.exception;
    import fluid.frame;

    static class Square : Frame {
        @safe:
        Color color;
        this(Color color) {
            this.color = color;
        }
        override void resizeImpl(Vector2) {
            minSize = Vector2(100, 100);
        }
        override void drawImpl(Rectangle, Rectangle inner) {
            io.drawRectangle(inner, color);
        }
    }

    alias square = simpleConstructor!Square;

    auto io = new HeadlessBackend;
    auto colors = [
        color!"7ff0a5",
        color!"17cccc",
        color!"a6a415",
        color!"cd24cf",
    ];
    auto root = vframe(
        .layout!"fill",
        square(.layout!"start",  colors[0]),
        square(.layout!"center", colors[1]),
        square(.layout!"end",    colors[2]),
        square(.layout!"fill",   colors[3]),
    );

    root.theme = Theme.init.derive(
        rule!Frame(Rule.backgroundColor = color!"1c1c1c")
    );
    root.io = io;

    // Test the layout
    {

        root.draw();

        // Each square in order
        io.assertRectangle(Rectangle(0, 0, 100, 100), colors[0]);
        io.assertRectangle(Rectangle(350, 100, 100, 100), colors[1]);
        io.assertRectangle(Rectangle(700, 200, 100, 100), colors[2]);

        // Except the last one, which is turned into a rectangle by "fill"
        // A proper rectangle class would change its target rectangles to keep aspect ratio
        io.assertRectangle(Rectangle(0, 300, 800, 100), colors[3]);

    }

    // Now do the same, but expand each node
    {

        io.nextFrame;

        foreach (child; root.children) {
            child.layout.expand = 1;
        }

        root.draw().assertThrown!AssertError;  // Oops, forgot to resize!
        root.updateSize;
        root.draw();

        io.assertRectangle(Rectangle(0, 0, 100, 100), colors[0]);
        io.assertRectangle(Rectangle(350, 175, 100, 100), colors[1]);
        io.assertRectangle(Rectangle(700, 350, 100, 100), colors[2]);
        io.assertRectangle(Rectangle(0, 450, 800, 150), colors[3]);

    }

    // Change Y alignment
    {

        io.nextFrame;

        root.children[0].layout = .layout!(1, "start", "end");
        root.children[1].layout = .layout!(1, "center", "fill");
        root.children[2].layout = .layout!(1, "end", "start");
        root.children[3].layout = .layout!(1, "fill", "center");

        root.updateSize;
        root.draw();

        io.assertRectangle(Rectangle(0, 50, 100, 100), colors[0]);
        io.assertRectangle(Rectangle(350, 150, 100, 150), colors[1]);
        io.assertRectangle(Rectangle(700, 300, 100, 100), colors[2]);
        io.assertRectangle(Rectangle(0, 475, 800, 100), colors[3]);

    }

    // Try different expand values
    {

        io.nextFrame;

        root.children[0].layout = .layout!(0, "center", "fill");
        root.children[1].layout = .layout!(1, "center", "fill");
        root.children[2].layout = .layout!(2, "center", "fill");
        root.children[3].layout = .layout!(3, "center", "fill");

        root.updateSize;
        root.draw();

        // The first rectangle doesn't expand so it should be exactly 100×100 in size
        io.assertRectangle(Rectangle(350, 0, 100, 100), colors[0]);

        // The remaining space is 500px, so divided into 1+2+3=6 pieces, it should be about 83.33px per piece
        io.assertRectangle(Rectangle(350, 100.00, 100,  83.33), colors[1]);
        io.assertRectangle(Rectangle(350, 183.33, 100, 166.66), colors[2]);
        io.assertRectangle(Rectangle(350, 350.00, 100, 250.00), colors[3]);

    }

}
