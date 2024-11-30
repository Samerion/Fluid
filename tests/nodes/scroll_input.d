module nodes.scroll_input;

import fluid;

@safe:

unittest {

    import std.range;

    Button btn;

    auto io = new HeadlessBackend(Vector2(200, 100));
    auto root = vscrollFrame(
        layout!"fill",
        btn = button(layout!"fill", "Button to test hover slipping", delegate { assert(false); }),
        label("Text long enough to overflow this very small viewport and create a scrollbar"),
    );

    root.io = io;
    root.draw();

    // Grab the scrollbar
    io.nextFrame;
    io.mousePosition = Vector2(195, 10);
    io.press;
    root.draw();

    // Drag the scrollbar 10 pixels lower
    io.nextFrame;
    io.mousePosition = Vector2(195, 20);
    root.draw();

    // Note down the difference
    const scrollDiff = root.scroll;

    // Drag the scrollbar 10 pixels lower, but also move it out of the scrollbar's area
    io.nextFrame;
    io.mousePosition = Vector2(150, 30);
    root.draw();

    const target = scrollDiff*2;

    assert(target-1 <= root.scroll && root.scroll <= target+1,
        "Scrollbar should operate at the same rate, even if the cursor is outside");

    // Make sure the button is hovered
    io.nextFrame;
    io.mousePosition = Vector2(150, 20);
    root.draw();
    assert(root.tree.hover is root.scrollBar.handle, "The scrollbar should retain hover control");
    assert(btn.isHovered, "The button has to be hovered");

    // Release the mouse while it's hovering the button
    io.nextFrame;
    io.release;
    root.draw();
    assert(btn.isHovered);
    // No event should trigger

}

