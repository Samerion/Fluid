module actions.scroll_into_view_action;

import std.math;
import std.array;
import std.range;
import std.algorithm;

import fluid;
import nodes.scroll;

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

@("ScrollIntoViewAction doesn't affect siblings of selected node")
unittest {
    ScrollFrame parent;
    ScrollFrame siblingBefore;
    ScrollFrame siblingAfter;
    Frame target;

    auto root = sizeLock!testSpace(
        .sizeLimit(100, 100),
        parent = vscrollFrame(
            .layout!(1, "fill"),
            siblingBefore = sizeLock!vscrollFrame(
                .sizeLimit(100, 100),
                tallBox(),
            ),
            target = sizeLock!vframe(
                .sizeLimit(100, 100),
            ),
            siblingAfter = sizeLock!vscrollFrame(
                .sizeLimit(100, 100),
                tallBox(),
            ),
        ),
    );

    root.draw();
    siblingBefore.scroll = 500;
    siblingAfter.scroll = 500;
    target
        .scrollIntoView
        .runWhileDrawing(root);

    assert(parent.scroll == 100);
    assert(siblingBefore.scroll == 500);
    assert(siblingAfter.scroll == 500);
}

@("ScrollIntoViewAction works recursively")
unittest {
    ScrollFrame[3] ancestors;
    Frame target;
    auto root = sizeLock!testSpace(
        ancestors[0] = sizeLock!vscrollFrame(
            .sizeLimit(100, 100),
            tallBox(),
            ancestors[1] = sizeLock!vscrollFrame(
                .sizeLimit(100, 100),
                tallBox(),
                ancestors[2] = sizeLock!vscrollFrame(
                    .sizeLimit(100, 100),
                    tallBox(),
                    target = sizeLock!vframe(
                        .sizeLimit(20, 100),
                    ),
                ),
            ),
        ),
    );

    root.theme = Theme(
        rule!Frame(
            Rule.backgroundColor = color("#f00"),
        ),
    );

    root.draw();
    target
        .scrollIntoView()
        .runWhileDrawing(root);

    assert(ancestors[0].scroll == 5250);
    assert(ancestors[1].scroll == 5250);
    assert(ancestors[2].scroll == 5250);

    root.drawAndAssert(
        target.isDrawn.at(0, 0),
        target.drawsRectangle(0, 0, 20, 100),
    );
}
