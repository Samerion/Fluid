module nodes.scroll_input;

import fluid;

@safe:

alias tallBox = nodeBuilder!TallBox;

class TallBox : Node {

    override void resizeImpl(Vector2) {
        minSize = Vector2(40, 5250);
    }

    override void drawImpl(Rectangle, Rectangle) {

    }

}

@("ScrollInput draws a track and a handle")
unittest {

    auto frame = sizeLock!vscrollFrame(
        .sizeLimit(250, 250),
        nullTheme.derive(
            rule!ScrollInput(
                Rule.backgroundColor = color("#f00"),
            ),
            rule!ScrollInputHandle(
                Rule.backgroundColor = color("#00f"),
            ),
        ),
        tallBox(),
    );
    auto root = testSpace(frame);

    root.drawAndAssert(
        frame.scrollBar       .drawsRectangle(240,   0, 10, 250).ofColor("#ff0000"),
        frame.scrollBar.handle.drawsRectangle(240,   0, 10,  50).ofColor("#0000ff"),
    );
    frame.scroll = 2500;
    root.drawAndAssert(
        frame.scrollBar       .drawsRectangle(240,   0, 10, 250).ofColor("#ff0000"),
        frame.scrollBar.handle.drawsRectangle(240, 100, 10,  50).ofColor("#0000ff"),
    );

}

@("ScrollInput works by dragging")
unittest {

    import std.range;

    Button btn;

    auto frame = sizeLock!vscrollFrame(
        .sizeLimit(200, 100),
        btn = button(.layout!"fill", "Button to test hover slipping", delegate { assert(false); }),
        label("Text long enough to overflow this very small viewport and create a scrollbar"),
    );
    auto hover = hoverChain(
        .nullTheme,
        frame
    );
    auto root = hover;

    root.draw();

    float scrollDiff;

    // Grab the scrollbar
    hover.point(195, 10)
        .then((a) {
            a.press(false);

            // Drag the scrollbar 10 pixels lower
            return a.move(195, 20);
        })
        .then((a) {
            a.press(false);

            // Note down the difference in scroll
            scrollDiff = frame.scroll;

            // Drag the scrollbar 10 pixels lower, but also move it out of the scrollbar's area
            return a.move(150, 30);
        })
        .then((a) {
            const target = scrollDiff*2;

            assert(target-1 <= frame.scroll && frame.scroll <= target+1,
                "Scrollbar should operate at the same rate, even if the cursor is outside");

            a.press();

            // Make sure the button is hovered
            return a.move(150, 20);
        })
        .then((a) {
            assert(a.isHovered(frame.scrollBar.handle), "The scrollbar should retain hover control");

            // Release the mouse while it's hovering the button
            return a.stayIdle;
        })
        .then((a) {
            assert(a.isHovered(btn));
        })
        .runWhileDrawing(root);

}
