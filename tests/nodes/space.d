module nodes.space;

import std.range;

import fluid;

@safe:

@("Space.minSize includes gaps")
unittest {

    import std.math;

    auto theme = nullTheme.derive(
        rule!Space(
            Rule.gap = 12,
        ),
    );

    auto root = vspace(
        theme,
        sizeLock!vframe(
            sizeLimitY = 200
        ),
        sizeLock!vframe(
            sizeLimitY = 200
        ),
        sizeLock!vframe(
            sizeLimitY = 200
        ),
    );
    root.draw();

    assert(isClose(root.getMinSize.y, 200 * 3 + 12 * 2));

}

@("vspace aligns nodes vertically, and hspace does it horizontally")
unittest {

    class Square : Node {

        CanvasIO canvasIO;
        Color color;

        this(Color color) {
            this.color = color;
        }

        override void resizeImpl(Vector2) {
            use(canvasIO);
            minSize = Vector2(50, 50);
        }

        override void drawImpl(Rectangle, Rectangle inner) {
            canvasIO.drawRectangle(inner, this.color);
        }

    }

    Square[6] squares;

    auto root = testSpace(
        squares[0] = new Square(color!"000"),
        squares[1] = new Square(color!"001"),
        squares[2] = new Square(color!"002"),
        hspace(
            squares[3] = new Square(color!"010"),
            squares[4] = new Square(color!"011"),
            squares[5] = new Square(color!"012"),
        ),
    );

    root.theme = nullTheme;
    root.drawAndAssert(

        // vspace
        squares[0].drawsRectangle(0,   0, 50, 50).ofColor("#000"),
        squares[1].drawsRectangle(0,  50, 50, 50).ofColor("#001"),
        squares[2].drawsRectangle(0, 100, 50, 50).ofColor("#002"),

        // hspace
        squares[3].drawsRectangle(  0, 150, 50, 50).ofColor("#010"),
        squares[4].drawsRectangle( 50, 150, 50, 50).ofColor("#011"),
        squares[5].drawsRectangle(100, 150, 50, 50).ofColor("#012"),
        
    );

}

@("Layout.expand splits space into columns")
unittest {

    import fluid.theme;

    Frame[3] frames;

    auto root = htestSpace(
        layout!"fill",
        frames[0] = vframe(layout!1),
        frames[1] = vframe(layout!2),
        frames[2] = vframe(layout!1),
    );
    root.theme = nullTheme.derive(
        rule!Frame(backgroundColor = color!"7d9"),
    );

    root.drawAndAssert(
        frames[0].drawsRectangle(0,   0, 0, 0).ofColor("#7d9"),
        frames[1].drawsRectangle(200, 0, 0, 0).ofColor("#7d9"),
        frames[2].drawsRectangle(600, 0, 0, 0).ofColor("#7d9"),
    );

    // Fill all nodes
    foreach (child; root.children) {
        child.layout.nodeAlign = NodeAlign.fill;
    }
    root.updateSize();

    root.drawAndAssert(
        frames[0].drawsRectangle(0,   0, 200, 600).ofColor("#7d9"),
        frames[1].drawsRectangle(200, 0, 400, 600).ofColor("#7d9"),
        frames[2].drawsRectangle(600, 0, 200, 600).ofColor("#7d9"),
    );

    const alignments = [NodeAlign.start, NodeAlign.center, NodeAlign.end];

    // Make Y alignment different across all three
    foreach (pair; root.children.zip(alignments)) {
        pair[0].layout.nodeAlign = pair[1];
    }
    root.updateSize();

    root.drawAndAssert(
        frames[0].drawsRectangle(  0,   0, 0, 0).ofColor("#7d9"),
        frames[1].drawsRectangle(400, 300, 0, 0).ofColor("#7d9"),
        frames[2].drawsRectangle(800, 600, 0, 0).ofColor("#7d9"),
    );

}

@("Space/Frame works with multiple levels of recursion")
unittest {

    import fluid.theme;

    Frame[5] frames;

    auto root = sizeLock!vtestSpace(
        .sizeLimit(270, 270),
        frames[0] = hframe(
            .layout!(1, "fill"),
            vspace(.layout!2),
            frames[1] = vframe(
                .layout!(1, "fill"),
                hspace(.layout!2),
                frames[2] = hframe(
                    .layout!(1, "fill"),
                    frames[3] = vframe(
                        .layout!(1, "fill"),
                        frames[4] = hframe(
                            .layout!(1, "fill")
                        ),
                        hspace(.layout!2),
                    ),
                    vspace(.layout!2),
                )
            ),
        ),
    );
    root.theme = nullTheme.derive(
        rule!Frame(backgroundColor = color!"0004"),
    );

    root.drawAndAssert(
        frames[0].drawsRectangle(  0,   0, 270, 270).ofColor("#0004"),
        frames[1].drawsRectangle(180,   0,  90, 270).ofColor("#0004"),
        frames[2].drawsRectangle(180, 180,  90,  90).ofColor("#0004"),
        frames[3].drawsRectangle(180, 180,  30,  90).ofColor("#0004"),
        frames[4].drawsRectangle(180, 180,  30,  30).ofColor("#0004"),
    );

}

@("Rounding errors when placing nodes https://git.samerion.com/Samerion/Fluid/issues/58")
unittest {

    import fluid.frame;
    import fluid.label;
    import fluid.structs;

    auto fill = layout!(1, "fill");
    auto myTheme = nullTheme.derive(
        rule!Label(Rule.backgroundColor = color!"#e65bb8"),
    );
    auto root = htestSpace(
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

    root.drawAndAssert(
        root.children[ 0].drawsRectangle( 0*800/12f, 0, 66.66, 600).ofColor("#e65bb8"),
        root.children[ 1].drawsRectangle( 1*800/12f, 0, 66.66, 600).ofColor("#e65bb8"),
        root.children[ 2].drawsRectangle( 2*800/12f, 0, 66.66, 600).ofColor("#e65bb8"),
        root.children[ 3].drawsRectangle( 3*800/12f, 0, 66.66, 600).ofColor("#e65bb8"),
        root.children[ 4].drawsRectangle( 4*800/12f, 0, 66.66, 600).ofColor("#e65bb8"),
        root.children[ 5].drawsRectangle( 5*800/12f, 0, 66.66, 600).ofColor("#e65bb8"),
        root.children[ 6].drawsRectangle( 6*800/12f, 0, 66.66, 600).ofColor("#e65bb8"),
        root.children[ 7].drawsRectangle( 7*800/12f, 0, 66.66, 600).ofColor("#e65bb8"),
        root.children[ 8].drawsRectangle( 8*800/12f, 0, 66.66, 600).ofColor("#e65bb8"),
        root.children[ 9].drawsRectangle( 9*800/12f, 0, 66.66, 600).ofColor("#e65bb8"),
        root.children[10].drawsRectangle(10*800/12f, 0, 66.66, 600).ofColor("#e65bb8"),
        root.children[11].drawsRectangle(11*800/12f, 0, 66.66, 600).ofColor("#e65bb8"));

}

@("Space respects gap")
unittest {

    import fluid.frame;
    import fluid.theme;
    import fluid.structs : layout;

    auto theme = nullTheme.derive(
        rule!Space(gap = 4),
        rule!Frame(backgroundColor = color("#f00")),
    );
    auto root = vtestSpace(
        layout!"fill",
        theme,
        vframe(layout!(1, "fill")),
        vframe(layout!(1, "fill")),
        vframe(layout!(1, "fill")),
        vframe(layout!(1, "fill")),
    );

    root.drawAndAssert(
        root.children[0].drawsRectangle(0,   0, 800, 147).ofColor("#f00"),
        root.children[1].drawsRectangle(0, 151, 800, 147).ofColor("#f00"),
        root.children[2].drawsRectangle(0, 302, 800, 147).ofColor("#f00"),
        root.children[3].drawsRectangle(0, 453, 800, 147).ofColor("#f00"));

}

@("Gaps do not apply to invisible children")
unittest {

    import fluid.theme;

    auto theme = nullTheme.derive(
        rule!Space(gap = 4),
    );

    auto spy = new class Space {

        Vector2 position;

        override void drawImpl(Rectangle outer, Rectangle inner) {
            position = outer.start;
        }
        
    };

    auto root = vspace(
        theme,
        hspace(),
        hspace(),
        hspace(),
        spy,
    );

    root.draw();

    assert(spy.position == Vector2(0, 12));

    // Hide one child
    root.children[0].hide();
    root.draw();

    assert(spy.position == Vector2(0, 8));

}

@("Applied style.gap depends on axis")
unittest {

    auto theme = nullTheme.derive(
        rule!Space(
            Rule.gap = [2, 4],
        ),
    );

    class Warden : Space {

        Rectangle outer;

        override void drawImpl(Rectangle outer, Rectangle inner) {
            super.drawImpl(this.outer = outer, inner);
        }

    }

    Warden[4] wardens;

    auto root = vspace(
        theme,
        hspace(
            wardens[0] = new Warden,
            wardens[1] = new Warden,
        ),
        vspace(
            wardens[2] = new Warden,
            wardens[3] = new Warden,
        ),
    );

    root.draw();
    
    assert(wardens[0].outer.start == Vector2(0, 0));
    assert(wardens[1].outer.start == Vector2(2, 0));
    assert(wardens[2].outer.start == Vector2(0, 4));
    assert(wardens[3].outer.start == Vector2(0, 8));

}
