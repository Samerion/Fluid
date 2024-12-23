module nodes.map_frame;

import fluid;

@safe:

@("MapFrame lays nodes out differently based on their drop vectors")
unittest {

    import fluid.space;
    import fluid.structs : layout;

    class RectangleSpace : Space {

        CanvasIO canvasIO;
        Color color;

        this(Color color) @safe {
            this.color = color;
        }

        override void resizeImpl(Vector2) @safe {
            use(canvasIO);
            minSize = Vector2(10, 10);
        }

        override void drawImpl(Rectangle outer, Rectangle inner) @safe {
            canvasIO.drawRectangle(inner, color);
        }

    }

    RectangleSpace[9] spaces;

    auto root = mapFrame(
        layout!(1, "fill"),

        // Rectangles with same X and Y

        Vector2(50, 50),
        .dropVector!"start",
        spaces[0] = new RectangleSpace(color!"f00"),

        Vector2(50, 50),
        .dropVector!"center",
        spaces[1] = new RectangleSpace(color!"0f0"),

        Vector2(50, 50),
        .dropVector!"end",
        spaces[2] = new RectangleSpace(color!"00f"),

        // Rectangles with different Xs

        Vector2(50, 100),
        .dropVector!("start", "start"),
        spaces[3] = new RectangleSpace(color!"e00"),

        Vector2(50, 100),
        .dropVector!("center", "start"),
        spaces[4] = new RectangleSpace(color!"0e0"),

        Vector2(50, 100),
        .dropVector!("end", "start"),
        spaces[5] = new RectangleSpace(color!"00e"),

        // Overflowing rectangles
        Vector2(-10, -10),
        spaces[6] = new RectangleSpace(color!"f0f"),

        Vector2(20, -5),
        spaces[7] = new RectangleSpace(color!"0ff"),

        Vector2(-5, 20),
        spaces[8] = new RectangleSpace(color!"ff0"),
    );
    auto test = testSpace(.layout!"fill", nullTheme, root);

    foreach (preventOverflow; [false, true, false]) {

        root.preventOverflow = preventOverflow;
        test.drawAndAssert(

            // Every rectangle is attached to (50, 50) but using a different origin point
            // The first red rectangle is attached by its start corner, the green by center corner, and the blue by end
            // corner
            spaces[0].drawsRectangle(50, 50, 10, 10).ofColor("f00"),
            spaces[1].drawsRectangle(45, 45, 10, 10).ofColor("0f0"),
            spaces[2].drawsRectangle(40, 40, 10, 10).ofColor("00f"),

            // This is similar for the second triple of rectangles, but the Y axis is the same for every one of them
            spaces[3].drawsRectangle(50, 100, 10, 10).ofColor("e00"),
            spaces[4].drawsRectangle(45, 100, 10, 10).ofColor("0e0"),
            spaces[5].drawsRectangle(40, 100, 10, 10).ofColor("00e"));

        // Two rectangles overflow: one is completely outside the view, and one is only peeking in
        // With overflow disabled, they should both be moved strictly inside the mapFrame
        if (preventOverflow) {
            test.drawAndAssert(
                spaces[6].drawsRectangle(0, 0, 10, 10).ofColor("f0f"),
                spaces[7].drawsRectangle(20, 0, 10, 10).ofColor("0ff"),
                spaces[8].drawsRectangle(0, 20, 10, 10).ofColor("ff0"));
        }

        // With overflow enabled, these two overflows should now be allowed to stay outside
        else {
            test.drawAndAssert(
                spaces[6].drawsRectangle(-10, -10, 10, 10).ofColor("f0f"),
                spaces[7].drawsRectangle(20, -5, 10, 10).ofColor("0ff"),
                spaces[8].drawsRectangle(-5, 20, 10, 10).ofColor("ff0"));
        }

    }

}
