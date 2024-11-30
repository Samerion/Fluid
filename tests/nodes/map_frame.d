module nodes.map_frame;

import fluid;

@safe:

@("[TODO] Legacy: MapFrame lays nodes out differently based on their drop vectors")
unittest {

    import fluid.space;
    import fluid.structs : layout;

    class RectangleSpace : Space {

        Color color;

        this(Color color) @safe {
            this.color = color;
        }

        override void resizeImpl(Vector2) @safe {
            minSize = Vector2(10, 10);
        }

        override void drawImpl(Rectangle outer, Rectangle inner) @safe {
            io.drawRectangle(inner, color);
        }

    }

    auto io = new HeadlessBackend;
    auto root = mapFrame(
        layout!"fill",

        // Rectangles with same X and Y

        Vector2(50, 50),
        .dropVector!"start",
        new RectangleSpace(color!"f00"),

        Vector2(50, 50),
        .dropVector!"center",
        new RectangleSpace(color!"0f0"),

        Vector2(50, 50),
        .dropVector!"end",
        new RectangleSpace(color!"00f"),

        // Rectangles with different Xs

        Vector2(50, 100),
        .dropVector!("start", "start"),
        new RectangleSpace(color!"e00"),

        Vector2(50, 100),
        .dropVector!("center", "start"),
        new RectangleSpace(color!"0e0"),

        Vector2(50, 100),
        .dropVector!("end", "start"),
        new RectangleSpace(color!"00e"),

        // Overflowing rectangles
        Vector2(-10, -10),
        new RectangleSpace(color!"f0f"),

        Vector2(20, -5),
        new RectangleSpace(color!"0ff"),

        Vector2(-5, 20),
        new RectangleSpace(color!"ff0"),
    );

    root.io = io;
    root.theme = nullTheme;

    foreach (preventOverflow; [false, true, false]) {

        root.preventOverflow = preventOverflow;
        root.draw();

        // Every rectangle is attached to (50, 50) but using a different origin point
        // The first red rectangle is attached by its start corner, the green by center corner, and the blue by end
        // corner
        io.assertRectangle(Rectangle(50, 50, 10, 10), color!"f00");
        io.assertRectangle(Rectangle(45, 45, 10, 10), color!"0f0");
        io.assertRectangle(Rectangle(40, 40, 10, 10), color!"00f");

        // This is similar for the second triple of rectangles, but the Y axis is the same for every one of them
        io.assertRectangle(Rectangle(50, 100, 10, 10), color!"e00");
        io.assertRectangle(Rectangle(45, 100, 10, 10), color!"0e0");
        io.assertRectangle(Rectangle(40, 100, 10, 10), color!"00e");

        if (preventOverflow) {

            // Two rectangles overflow: one is completely outside the view, and one is only peeking in
            // With overflow disabled, they should both be moved strictly inside the mapFrame
            io.assertRectangle(Rectangle(0, 0, 10, 10), color!"f0f");
            io.assertRectangle(Rectangle(20, 0, 10, 10), color!"0ff");
            io.assertRectangle(Rectangle(0, 20, 10, 10), color!"ff0");

        }

        else {

            // With overflow enabled, these two overflows should now be allowed to stay outside
            io.assertRectangle(Rectangle(-10, -10, 10, 10), color!"f0f");
            io.assertRectangle(Rectangle(20, -5, 10, 10), color!"0ff");
            io.assertRectangle(Rectangle(-5, 20, 10, 10), color!"ff0");

        }

    }

}

