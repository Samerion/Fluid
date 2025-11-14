module actions.scroll_into_view_action;

import std.math;
import std.array;
import std.range;
import std.algorithm;

import fluid;

@safe:

@("ScrollIntoViewAction works")
unittest {

    const viewportHeight = 10;

    Label[3] labels;

    auto frame = vscrollFrame(
        .layout!(1, "fill"),
        labels[0] = label("a"),
        labels[1] = label("b"),
        labels[2] = label("c"),
    );
    auto root = sizeLock!testSpace(
        .nullTheme,
        .sizeLimit(10, viewportHeight),
        .cropViewport,
        frame
    );

    frame.scrollBar.width = 0;  // TODO replace this with scrollBar.hide()

    // Prepare scrolling
    // Note: Changes made when scrolling will be visible during the next frame
    frame.children[1].scrollIntoView;
    root.draw();

    // No theme so everything is as compact as it can be: the first label should be at the very top
    // It is reasonable to assume the text will be larger than 10 pixels (viewport height)
    // Other text will not render, since it's offscreen
    root.drawAndAssert(
        labels[0].doesNotDrawImages(),
        labels[1].drawsImage().at(0, viewportHeight - labels[1].text.size.y),
        labels[2].doesNotDrawImages(),
    );
    // TODO Because the label was hidden below the viewport, Fluid will align the bottom of the selected node with the
    // viewport which probably isn't appropriate in case *like this* where it should reveal the top of the node.

    // auto texture1 = io.textures.front;
    // assert(isClose(texture1.position.y + texture1.height, viewportHeight));
    assert(isClose(frame.scroll, (frame.maxScroll + 10) * 2/3 - 10));

    // TODO more tests. Scrolling while already in the viewport, scrolling while partially out of the view, etc.

}
