// Meta!
module nodes.test_space;

import fluid;

@safe:

alias myImage = nodeBuilder!MyImage;
class MyImage : Node {

    CanvasIO canvasIO;
    DrawableImage image;

    this(Image image = Image.init) {
        this.image = DrawableImage(image);
    }

    override void resizeImpl(Vector2 space) {
        use(canvasIO);
        load(canvasIO, image);
    }

    override void drawImpl(Rectangle outer, Rectangle inner) {
        image.draw(inner);
    }

}

alias emitSignal = nodeBuilder!EmitSignal;
class EmitSignal : Node {

    DebugSignalIO debugSignalIO;
    string signal;

    this(string signal) {
        this.signal = signal;
    }

    override void resizeImpl(Vector2) {
        require(debugSignalIO);
        minSize = Vector2();
    }

    override void drawImpl(Rectangle, Rectangle) {
        debugSignalIO.emitSignal(signal);
    }

}

@("TestSpace can perform basic tests with draws, drawsRectangle and doesNotDraw")
unittest {

    class MyNode : Node {

        CanvasIO canvasIO;
        auto targetRectangle = Rectangle(0, 0, 10, 10);

        override void resizeImpl(Vector2) {
            require(canvasIO);
        }

        override void drawImpl(Rectangle, Rectangle) {
            canvasIO.drawRectangle(targetRectangle, color("#f00"));
            targetRectangle.x += 1;
        }

    }

    auto myNode = new MyNode;
    auto space = testSpace(myNode);
    space.drawAndAssert(
        space.doesNotDraw(),
        myNode.drawsRectangle(0, 0, 10, 10),
    );
    space.drawAndAssert(
        space.doesNotDraw(),
        myNode.drawsRectangle(1, 0, 10, 10),
    );
    space.drawAndAssert(
        space.doesNotDraw(),
        myNode.drawsRectangle(2, 0, 10, 10).ofColor("#f00"),
    );
    space.drawAndAssert(
        space.doesNotDraw(),
        myNode.draws(),
    );
    space.drawAndAssertFailure(
        space.draws(),
    );
    space.drawAndAssertFailure(
        myNode.doesNotDraw()
    );
    space.drawAndAssert(
        myNode.drawsRectangle(),
    );
    space.drawAndAssert(
        myNode.drawsRectangle().ofColor("#f00"),
    );
    space.drawAndAssertFailure(
        myNode.drawsRectangle().ofColor("#500"),
    );
    space.drawAndAssertFailure(
        space.drawsRectangle().ofColor("#500"),
    );

}

@("TestProbe correctly handles node exits")
unittest {

    import fluid.label;

    static class Surround : Space {

        CanvasIO canvasIO;

        this(Node[] nodes...) @safe {
            super(nodes);
        }

        override void resizeImpl(Vector2 space) {
            super.resizeImpl(space);
            use(canvasIO);
        }

        override void drawImpl(Rectangle outer, Rectangle inner) {
            canvasIO.drawRectangle(outer, color("#a00"));
            super.drawImpl(outer, inner);
            canvasIO.drawRectangle(outer, color("#0a0"));
        }

    }

    alias surround = nodeBuilder!Surround;

    {
        auto myLabel = label("!");
        auto root = surround(
            myLabel,
        );
        auto test = testSpace(root);

        test.drawAndAssert(
            root.drawsRectangle(),
            myLabel.isDrawn(),
            root.drawsRectangle(),
        );
        test.drawAndAssertFailure(
            root.drawsRectangle(),
            myLabel.isDrawn(),
            root.doesNotDraw(),
        );
        test.drawAndAssertFailure(
            root.doesNotDraw(),
            myLabel.isDrawn(),
            root.drawsRectangle(),
        );
    }
    {
        auto myLabel = label("!");
        auto wrapper = vspace(myLabel);
        auto root = surround(
            wrapper,
        );
        auto test = testSpace(root);

        test.drawAndAssert(
            root.drawsRectangle(),
                wrapper.isDrawn(),
                wrapper.doesNotDraw(),
                    myLabel.isDrawn(),
                wrapper.doesNotDraw(),
            root.drawsRectangle(),
        );
        test.drawAndAssert(
            root.drawsRectangle(),
                wrapper.isDrawn(),
                wrapper.doesNotDraw(),
            root.drawsRectangle(),
        );
        test.drawAndAssert(
            root.drawsRectangle(),
            root.drawsRectangle(),
            root.doesNotDraw(),
        );
        test.drawAndAssert(
            root.drawsRectangle(),
            root.doesNotDraw(),
                wrapper.isDrawn(),
            root.drawsRectangle(),
            root.doesNotDraw(),
        );
    }

}

@("TestSpace can handle images")
unittest {

    auto root = myImage();
    auto test = testSpace(root);

    // The image will be loaded and drawn
    test.drawAndAssert(
        root.drawsImage(root.image),
    );
    assert(test.countLoadedImages == 1);

    // The image will not be loaded, but it will be kept alive
    test.drawAndAssert(
        root.drawsImage(root.image),
    );
    assert(test.countLoadedImages == 1);

    // Request a resize — same situation
    test.updateSize();
    test.drawAndAssert(
        root.drawsImage(root.image),
    );
    assert(test.countLoadedImages == 1);

    // Hide the node: the node won't resize and the image will be freed
    root.hide();
    test.drawAndAssertFailure(
        root.isDrawn(),
    );
    assert(test.countLoadedImages == 0);

    // Show the node now and try again
    root.show();
    test.drawAndAssert(
        root.drawsImage(root.image),
    );
    assert(test.countLoadedImages == 1);

}

@("TestSpace: Two nodes with the same image will share resources")
unittest {

    auto image1 = myImage();
    auto image2 = myImage();
    auto test = testSpace(image1, image2);

    assert(image1.image == image2.image);

    // Two nodes draw the same image — counts as one
    test.drawAndAssert(
        image1.drawsImage(image1.image),
        image2.drawsImage(image2.image),
    );
    assert(test.countLoadedImages == 1);

    // Hide one image
    image1.hide();
    test.drawAndAssert(
        image2.drawsImage(image2.image),
    );
    test.drawAndAssertFailure(
        image1.drawsImage(image1.image),
    );
    assert( test.isImageLoaded(image1.image));
    assert( test.isImageLoaded(image2.image));
    assert(test.countLoadedImages == 1);

    // Hide both — the images should unload
    image2.hide();
    test.drawAndAssertFailure(
        image1.drawsImage(image1.image),
    );
    test.drawAndAssertFailure(
        image2.drawsImage(image2.image),
    );
    assert(!test.isImageLoaded(image1.image));
    assert(!test.isImageLoaded(image2.image));
    assert(test.countLoadedImages == 0);

    // Show one again
    image2.show();
    test.drawAndAssert(
        image2.drawsImage(image2.image),
    );
    test.drawAndAssertFailure(
        image1.drawsImage(image1.image),
    );
    assert( test.isImageLoaded(image2.image));
    assert(test.countLoadedImages == 1);

}

@("TestSpace correctly manages lifetime of multiple resources")
unittest {

    auto image1 = myImage(
        generateColorImage(4, 4,
            color("#f00")
        )
    );
    auto image2 = myImage(
        generateColorImage(4, 4,
            color("#0f0")
        )
    );
    auto root = testSpace(image1, image2);

    // Draw both images
    root.drawAndAssert(
        image1.drawsImage(image1.image),
        image2.drawsImage(image2.image),
    );
    assert(root.countLoadedImages == 2);
    assert(root.isImageLoaded(image1.image));
    assert(root.isImageLoaded(image2.image));

    // Unload the second one
    image1.hide();
    root.drawAndAssert(
        image2.drawsImage(image2.image),
    );
    root.drawAndAssertFailure(
        image1.drawsImage(image1.image),
    );
    assert(root.countLoadedImages == 1);
    assert(!root.isImageLoaded(image1.image));
    assert( root.isImageLoaded(image2.image));

}

@("TestSpace / CanvasIO recognizes tint")
unittest {

    import fluid.frame;
    import fluid.style;

    auto theme = nullTheme.derive(
        rule!Frame(
            Rule.backgroundColor = color("#aaa"),
            Rule.tint = color("#aaaa"),
        )
    );

    Frame[6] frames;

    auto root = testSpace(
        theme,
        frames[0] = vframe(
            frames[1] = vframe(
                frames[2] = vframe(
                    frames[3] = vframe(),
                    frames[4] = vframe(),
                ),
                frames[5] = vframe(),
            ),
        ),
    );

    root.drawAndAssert(
        frames[0].drawsRectangle().ofColor("#717171aa"),
        frames[1].drawsRectangle().ofColor("#4b4b4b71"),
        frames[2].drawsRectangle().ofColor("#3232324b"),
        frames[3].drawsRectangle().ofColor("#21212132"),
        frames[4].drawsRectangle().ofColor("#21212132"),
        frames[5].drawsRectangle().ofColor("#3232324b"),
    );

}

@("Tint can be locked to prevent changes")
unittest {

    import fluid.frame;
    import fluid.style;

    static class LockTint : Space {

        this(Ts...)(Ts args) {
            super(args);
        }

        override void drawImpl(Rectangle outer, Rectangle inner) {

            treeContext.lockTint();
            scope (exit) treeContext.unlockTint();

            super.drawImpl(outer, inner);

        }

    }

    alias lockTint = nodeBuilder!LockTint;

    auto theme = nullTheme.derive(
        rule!Frame(
            Rule.backgroundColor = color("#aaa"),
            Rule.tint = color("#aaaa"),
        )
    );

    Frame[7] frames;

    auto root = testSpace(
        theme,
        frames[0] = vframe(
            frames[1] = vframe(
                lockTint(
                    frames[2] = vframe(
                        frames[3] = vframe(),
                        frames[4] = vframe(),
                    ),
                    frames[5] = vframe(),
                ),
                frames[6] = vframe(),
            ),
        ),
    );

    root.drawAndAssert(
        frames[0].drawsRectangle().ofColor("#717171aa"),
        frames[1].drawsRectangle().ofColor("#4b4b4b71"),
        frames[2].drawsRectangle().ofColor("#4b4b4b71"),
        frames[3].drawsRectangle().ofColor("#4b4b4b71"),
        frames[4].drawsRectangle().ofColor("#4b4b4b71"),
        frames[5].drawsRectangle().ofColor("#4b4b4b71"),
        frames[6].drawsRectangle().ofColor("#3232324b"),
    );

}

@("TestSpace can capture and analyze debug signals")
unittest {

    EmitSignal[3] emitters;

    auto root = testSpace(
        emitters[0] = emitSignal("one"),
        emitters[1] = emitSignal("two"),
        emitters[2] = emitSignal("three"),
    );

    root.drawAndAssert(
        emitters[0].emits("one"),
        emitters[1].emits("two"),
        emitters[2].emits("three"),
    );

    root.drawAndAssertFailure(
        emitters[0].emits("two"),
    );

    root.drawAndAssertFailure(
        emitters[2].emits("one"),
    );

    assert(root.emitCount("one") == 3);
    assert(root.emitCount("two") == 3);
    assert(root.emitCount("three") == 3);

}
