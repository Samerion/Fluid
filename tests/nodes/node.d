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

@("isDisabled applies transitively")
unittest {

    int clicked;

    Button firstButton, secondButton;
    Space space;

    auto root = focusSpace(
        firstButton = button("One", delegate { clicked++; }),
        space       = vspace(
            secondButton = button("One", delegate { clicked++; }),
        ),
    );

    // Disable the space and press both buttons
    space.disable();
    root.draw();
    root.currentFocus = firstButton;
    root.runInputAction!(FluidInputAction.press);
    assert(clicked == 1);
    root.currentFocus = secondButton;
    root.runInputAction!(FluidInputAction.press);
    assert(clicked == 1);

    // Enable it
    space.enable();
    root.draw();
    root.currentFocus = secondButton;
    root.runInputAction!(FluidInputAction.press);
    assert(clicked == 2);

    // Disable the root
    root.disable();
    root.draw();
    root.currentFocus = secondButton;
    root.runInputAction!(FluidInputAction.press);
    assert(clicked == 2);
    root.currentFocus = firstButton;
    root.runInputAction!(FluidInputAction.press);
    assert(clicked == 2);

}
