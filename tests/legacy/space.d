@Migrated
module legacy.space;

import fluid;
import legacy;
import std.range;

@safe:

@("vspace aligns nodes vertically, and hspace does it horizontally")
@Migrated
unittest {

    class Square : Node {

        Color color;

        this(Color color) {
            this.color = color;
        }

        override void resizeImpl(Vector2) {
            minSize = Vector2(50, 50);
        }

        override void drawImpl(Rectangle, Rectangle inner) {
            io.drawRectangle(inner, this.color);
        }

    }

    auto io = new HeadlessBackend;
    auto root = vspace(
        new Square(color!"000"),
        new Square(color!"001"),
        new Square(color!"002"),
        hspace(
            new Square(color!"010"),
            new Square(color!"011"),
            new Square(color!"012"),
        ),
    );

    root.io = io;
    root.theme = nullTheme;
    root.draw();

    // vspace
    io.assertRectangle(Rectangle(0,   0, 50, 50), color!"000");
    io.assertRectangle(Rectangle(0,  50, 50, 50), color!"001");
    io.assertRectangle(Rectangle(0, 100, 50, 50), color!"002");

    // hspace
    io.assertRectangle(Rectangle(  0, 150, 50, 50), color!"010");
    io.assertRectangle(Rectangle( 50, 150, 50, 50), color!"011");
    io.assertRectangle(Rectangle(100, 150, 50, 50), color!"012");

}

@("Layout.expand splits space into columns")
@Migrated
unittest {

    import fluid.frame;
    import fluid.structs;

    auto io = new HeadlessBackend;
    auto root = hspace(
        layout!"fill",
        vframe(layout!1),
        vframe(layout!2),
        vframe(layout!1),
    );

    with (Rule)
    root.theme = nullTheme.derive(
        rule!Frame(backgroundColor = color!"7d9"),
    );
    root.io = io;

    // Frame 1
    {
        root.draw();
        io.assertRectangle(Rectangle(0,   0, 0, 0), color!"7d9");
        io.assertRectangle(Rectangle(200, 0, 0, 0), color!"7d9");
        io.assertRectangle(Rectangle(600, 0, 0, 0), color!"7d9");
    }

    // Fill all nodes
    foreach (child; root.children) {
        child.layout.nodeAlign = NodeAlign.fill;
    }
    root.updateSize();

    {
        io.nextFrame;
        root.draw();
        io.assertRectangle(Rectangle(  0, 0, 200, 600), color!"7d9");
        io.assertRectangle(Rectangle(200, 0, 400, 600), color!"7d9");
        io.assertRectangle(Rectangle(600, 0, 200, 600), color!"7d9");
    }

    const alignments = [NodeAlign.start, NodeAlign.center, NodeAlign.end];

    // Make Y alignment different across all three
    foreach (pair; root.children.zip(alignments)) {
        pair[0].layout.nodeAlign = pair[1];
    }

    {
        io.nextFrame;
        root.draw();
        io.assertRectangle(Rectangle(  0,   0, 0, 0), color!"7d9");
        io.assertRectangle(Rectangle(400, 300, 0, 0), color!"7d9");
        io.assertRectangle(Rectangle(800, 600, 0, 0), color!"7d9");
    }

}

@("Space/Frame works with multiple levels of recursion")
@Migrated
unittest {

    import fluid.frame;
    import fluid.structs;

    auto io = new HeadlessBackend(Vector2(270, 270));
    auto root = hframe(
        layout!"fill",
        vspace(layout!2),
        vframe(
            layout!(1, "fill"),
            hspace(layout!2),
            hframe(
                layout!(1, "fill"),
                vframe(
                    layout!(1, "fill"),
                    hframe(
                        layout!(1, "fill")
                    ),
                    hspace(layout!2),
                ),
                vspace(layout!2),
            )
        ),
    );

    with (Rule)
    root.theme = nullTheme.derive(
        rule!Frame(backgroundColor = color!"0004"),
    );
    root.io = io;
    root.draw();

    io.assertRectangle(Rectangle(  0,   0, 270, 270), color!"0004");
    io.assertRectangle(Rectangle(180,   0,  90, 270), color!"0004");
    io.assertRectangle(Rectangle(180, 180,  90,  90), color!"0004");
    io.assertRectangle(Rectangle(180, 180,  30,  90), color!"0004");
    io.assertRectangle(Rectangle(180, 180,  30,  30), color!"0004");

}

@("Rounding errors when placing nodes https://git.samerion.com/Samerion/Fluid/issues/58")
@Migrated
unittest {

    import fluid.frame;
    import fluid.label;
    import fluid.structs;

    auto fill = layout!(1, "fill");
    auto io = new HeadlessBackend;
    auto myTheme = nullTheme.derive(
        rule!Frame(Rule.backgroundColor = color!"#303030"),
        rule!Label(Rule.backgroundColor = color!"#e65bb8"),
    );
    auto root = hframe(
        fill,
        myTheme,
        label(fill, "1"),
        label(fill, "2"),
        label(fill, "3"),
        label(fill, "4"),
        label(fill, "5"),
        label(fill, "6"),
        label(fill, "7"),
        label(fill, "8"),
        label(fill, "9"),
        label(fill, "10"),
        label(fill, "11"),
        label(fill, "12"),
    );

    root.io = io;
    root.draw();

    io.assertRectangle(Rectangle( 0*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 1*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 2*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 3*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 4*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 5*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 6*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 7*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 8*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 9*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle(10*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle(11*800/12f, 0, 66.66, 600), color!"#e65bb8");

}

@("Space respects gap")
@Migrated
unittest {

    import fluid.frame;
    import fluid.theme;
    import fluid.structs : layout;

    auto io = new HeadlessBackend;
    auto theme = nullTheme.derive(
        rule!Space(
            gap = 4,
        ),
        rule!Frame(
            backgroundColor = color("#f00"),
        ),
    );
    auto root = vspace(
        layout!"fill",
        theme,
        vframe(layout!(1, "fill")),
        vframe(layout!(1, "fill")),
        vframe(layout!(1, "fill")),
        vframe(layout!(1, "fill")),
    );

    root.io = io;
    root.draw();

    io.assertRectangle(Rectangle(0,   0, 800, 147), color("#f00"));
    io.assertRectangle(Rectangle(0, 151, 800, 147), color("#f00"));
    io.assertRectangle(Rectangle(0, 302, 800, 147), color("#f00"));
    io.assertRectangle(Rectangle(0, 453, 800, 147), color("#f00"));

}
