@Abandoned
module legacy.grid_frame;

// `GridFrame` tests have been omitted from the 0.8.0 test suite, because `GridFrame` is inherently flawed.

import fluid;
import legacy;

import std.algorithm;

@safe:

@("GridFrame places its children in a table-like grid")
unittest {

    import std.math;
    import std.array;
    import std.typecons;
    import fluid.label;

    auto io = new HeadlessBackend;
    auto root = gridFrame(
        .nullTheme,
        .layout!"fill",
        .segments!4,

        label("You can make tables and grids with Grid"),
        [
            label("This"),
            label("Is"),
            label("A"),
            label("Grid"),
        ],
        [
            label(.segments!2, "Multiple columns"),
            label(.segments!2, "For a single cell"),
        ]
    );

    root.io = io;
    root.draw();

    // Check layout parameters

    assert(root.layout == .layout!"fill");
    assert(root.segmentCount == 4);
    assert(root.children.length == 3);

    assert(cast(Label) root.children[0]);

    auto row1 = cast(GridRow) root.children[1];

    assert(row1);
    assert(row1.segmentCount == 4);
    assert(row1.children.all!"a.layout.expand == 0");

    auto row2 = cast(GridRow) root.children[2];

    assert(row2);
    assert(row2.segmentCount == 4);
    assert(row2.children.all!"a.layout.expand == 2");

    // Current implementation requires an extra frame to settle. This shouldn't be necessary.
    io.nextFrame;
    root.draw();

    // Each column should be 200px wide
    assert(root.segmentSizes == [200, 200, 200, 200]);

    const rowEnds = root.children.map!(a => a.getMinSize.y)
        .cumulativeFold!"a + b"
        .array;

    // Check if the drawing is correct
    // Row 0
    io.assertTexture(Rectangle(0, 0, root.children[0].getMinSize.tupleof), color!"fff");

    // Row 1
    foreach (i; 0..4) {

        const start = Vector2(i * 200, rowEnds[0]);

        assert(io.textures.canFind!(tex => tex.isStartClose(start)));

    }

    // Row 2
    foreach (i; 0..2) {

        const start = Vector2(i * 400, rowEnds[1]);

        assert(io.textures.canFind!(tex => tex.isStartClose(start)));

    }

}

@("GridFrame can guess the number of segments needed to divide space between its children")
unittest {

    import fluid.label;

    // Nodes are to span segments in order:
    // 1. One label to span 6 segments
    // 2. Each 3 segments
    // 3. Each 2 segments
    auto g = gridFrame(
        [ label("") ],
        [ label(""), label("") ],
        [ label(""), label(""), label("") ],
    );

    g.backend = new HeadlessBackend;
    g.draw();

    assert(g.segmentCount == 6);

}


@("GridFrame rows can have gaps")
unittest {

    auto theme = nullTheme.derive(
        rule!GridFrame(
            Rule.gap = 4,
        ),
        rule!GridRow(
            Rule.gap = 6,
        ),
    );

    static class Warden : Frame {

        Vector2 position;

        override void resizeImpl(Vector2 space) {
            super.resizeImpl(space);
            minSize = Vector2(10, 10);
        }

        override void drawImpl(Rectangle outer, Rectangle) {
            position = outer.start;
        }

    }

    alias warden = simpleConstructor!Warden;

    Warden[3] row1;
    Warden[6] row2;

    auto grid = gridFrame(
        theme,
        [
            row1[0] = warden(.segments!2),
            row1[1] = warden(.segments!2),
            row1[2] = warden(.segments!2),
        ],
        [
            row2[0] = warden(),
            row2[1] = warden(),
            row2[2] = warden(),
            row2[3] = warden(),
            row2[4] = warden(),
            row2[5] = warden(),
        ],
    );

    grid.draw();

    assert(row1[0].position == Vector2( 0, 0));
    assert(row1[1].position == Vector2(32, 0));
    assert(row1[2].position == Vector2(64, 0));

    assert(row2[0].position == Vector2( 0, 14));
    assert(row2[1].position == Vector2(16, 14));
    assert(row2[2].position == Vector2(32, 14));
    assert(row2[3].position == Vector2(48, 14));
    assert(row2[4].position == Vector2(64, 14));
    assert(row2[5].position == Vector2(80, 14));

}
