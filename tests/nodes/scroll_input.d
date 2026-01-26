module nodes.scroll_input;

import std.range;
import fluid;
import nodes.scroll;

@safe:

@("ScrollInput draws a track and a handle")
unittest {

    auto frame = sizeLock!vscrollFrame(
        .sizeLimit(250, 250),
        .testTheme,
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

    Button btn;

    auto frame = sizeLock!vscrollFrame(
        .testTheme,
        .sizeLimit(200, 100),
        btn = button(.layout!"fill", "Button to test hover slipping", delegate { assert(false); }),
        label("Text long enough to overflow this very small viewport and create a scrollbar"),
    );
    auto hover = hoverChain();
    auto root = testSpace(
        chain(
            inputMapChain(),
            hover,
            frame,
        )
    );

    root.draw();

    float scrollDiff;

    // Grab the scrollbar
    hover.point(195, 10)
        .then((a) {
            assert(a.isHovered(frame.scrollBar.handle));
            a.press(false);

            // Drag the scrollbar 10 pixels lower
            return a.move(195, 20);
        })
        .then((a) {
            a.press(false);

            // Note down the difference in scroll
            scrollDiff = frame.scroll;
            assert(scrollDiff > 5);

            // Drag the scrollbar 10 pixels lower, but also move it out of the scrollbar's area
            return a.move(150, 30);
        })
        .then((a) {
            const target = scrollDiff*2;

            a.press(false);
            assert(target-1 <= frame.scroll && frame.scroll <= target+1,
                "Scrollbar should operate at the same rate, even if the cursor is outside");

            // Make sure the button is hovered
            return a.move(150, 20);
        })
        .then((a) {
            assert(a.isHovered(frame.scrollBar.handle),
                "The scrollbar should retain hover control");

            // Release the mouse while it's hovering the button
            return a.stayIdle;
        })
        .then((a) {
            assert(a.isHovered(btn));
        })
        .runWhileDrawing(root);

}

@("ScrollInputHandle passes focus to ScrollInput when clicked (with HoverChain)")
unittest {
    auto frame = sizeLock!vscrollFrame(
        .sizeLimit(100, 100),
        .testTheme,
        tallBox(),
    );
    auto hover = hoverChain(frame);
    auto focus = focusChain(hover);
    auto root = focus;

    root.draw();

    hover.point(95, 5)
        .then((a) {
            a.press();
        })
        .runWhileDrawing(root);

    () @trusted {
        assert(focus.currentFocus == frame.scrollBar);
    }();
}
