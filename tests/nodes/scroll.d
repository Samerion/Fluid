module nodes.scroll;

import fluid;
import fluid.future.pipe;

@safe:

alias tallBox = nodeBuilder!TallBox;

class TallBox : Node {

    CanvasIO canvasIO;

    override void resizeImpl(Vector2) {
        require(canvasIO);
        minSize = Vector2(40, 5250);
    }

    override void drawImpl(Rectangle outer, Rectangle) {
        style.drawBackground(io, canvasIO, outer);
    }

}

alias wideBox = nodeBuilder!WideBox;

class WideBox : Node {

    CanvasIO canvasIO;

    override void resizeImpl(Vector2) {
        require(canvasIO);
        minSize = Vector2(5250, 40);
    }

    override void drawImpl(Rectangle outer, Rectangle) {
        style.drawBackground(io, canvasIO, outer);
    }

}

Theme testTheme;

static this() {
    testTheme = nullTheme.derive(
        rule!ScrollFrame(
            Rule.backgroundColor = color("#555"),
        ),
        rule!ScrollInput(
            Rule.backgroundColor = color("#f00"),
        ),
        rule!ScrollInputHandle(
            Rule.backgroundColor = color("#00f"),
        ),
    );
}

@("ScrollFrame crops and scrolls its content")
unittest {

    auto box = tallBox();
    auto frame = sizeLock!vscrollFrame(
        .sizeLimit(400, 250),
        box,
    );
    auto root = testSpace(
        .testTheme,
        frame
    );

    root.drawAndAssert(
         frame.cropsTo(0, 0, 390, 250),
         frame.drawsRectangle(0, 0, 390, 250).ofColor("#555555"),
         box.drawsRectangle(0, 0, 40, 5250),
         frame.resetsCrop(),
    );

    frame.scroll = 100;
    root.drawAndAssert(
         frame.cropsTo(0, 0, 390, 250),
         frame.drawsRectangle(0, 0, 390, 250).ofColor("#555555"),
         box.drawsRectangle(0, -100, 40, 5250),
         frame.resetsCrop(),
    );

    frame.scrollEnd();
    root.drawAndAssert(
         frame.cropsTo(0, 0, 390, 250),
         frame.drawsRectangle(0, 0, 390, 250).ofColor("#555555"),
         box.drawsRectangle(0, -5000, 40, 5250),
         frame.resetsCrop(),
    );

}

@("ScrollFrames can be nested")
unittest {

    auto box = tallBox();
    auto innerFrame = sizeLock!vscrollFrame(
        .sizeLimit(400, 500),
        box,
    );
    auto frame = sizeLock!vscrollFrame(
        .sizeLimit(400, 250),
        innerFrame,
        tallBox(),
    );
    auto root = testSpace(
        .testTheme,
        frame
    );

    root.drawAndAssert(
        frame.cropsTo       (0, 0, 390, 250),
        frame.drawsRectangle(0, 0, 390, 250),
        innerFrame.cropsTo       (0, 0, 380, 250),  // 250, not 500, because the boxes
        innerFrame.drawsRectangle(0, 0, 380, 500),  // intersect
        box.drawsRectangle(0, 0, 40, 5250),
        innerFrame.cropsTo       (0, 0, 390, 250),
        frame.resetsCrop(),
    );

    frame.scroll = 400;
    root.drawAndAssert(
        frame.cropsTo       (0, 0, 390, 250),
        frame.drawsRectangle(0, 0, 390, 250),
        innerFrame.cropsTo       (0,    0, 380, 100),
        innerFrame.drawsRectangle(0, -400, 380, 500),
        box.drawsRectangle(0, -400, 40, 5250),
        innerFrame.cropsTo       (0, 0, 390, 250),
        frame.resetsCrop(),
    );

}

@("ScrollFrames can be horizontal or vertical")
unittest {

    auto vbox = tallBox();
    auto hbox = wideBox();
    auto vf = sizeLock!vscrollFrame(
        .sizeLimit(300, 300),
        vbox,
    );
    auto hf = sizeLock!hscrollFrame(
        .sizeLimit(300, 300),
        hbox,
    );
    auto hover = hoverChain(
        vspace(vf, hf),
    );
    auto root = vtestSpace(
        .testTheme,
        hover,
    );

    root.drawAndAssert(
        vf.cropsTo         (0, 0, 290, 300),
        vf.drawsRectangle  (0, 0, 290, 300),
        vbox.drawsRectangle(0, 0, 40, 5250),
        vf.resetsCrop      (),

        hf.cropsTo         (0, 300, 300, 290),
        hf.drawsRectangle  (0, 300, 300, 290),
        hbox.drawsRectangle(0, 300, 5250, 40),
        hf.resetsCrop      (),
    );

    join(
        hover.point(100, 100).scroll(30, 90),
        hover.point(100, 400).scroll(20, 80),
    )
        .runWhileDrawing(root, 1);

    assert(vf.scroll == 90);
    assert(hf.scroll == 20);

    root.drawAndAssert(
        vf.cropsTo         (0,   0, 290,  300),
        vf.drawsRectangle  (0,   0, 290,  300),
        vbox.drawsRectangle(0, -90,  40, 5250),
        vf.resetsCrop      (),

        hf.cropsTo         (  0, 300,  300, 290),
        hf.drawsRectangle  (  0, 300,  300, 290),
        hbox.drawsRectangle(-20, 300, 5250,  40),
        hf.resetsCrop      (),
    );

}
