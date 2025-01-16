module nodes.drag_slot;

import fluid;

@safe:

alias resizable = nodeBuilder!Resizable;

class Resizable : Node {

    Vector2 size;

    this(Vector2 size) {
        this.size = size;
    }

    override void resizeImpl(Vector2) {
        minSize = size;
    }

    override void drawImpl(Rectangle, Rectangle) {

    }

    override bool inBoundsImpl(Rectangle, Rectangle, Vector2) {
        return false;
    }

}

@("DragSlot ignores gap if the handle is hidden")
unittest {

    import std.algorithm;
    import fluid.theme;

    auto theme = nullTheme.derive(
        rule!DragSlot(gap = 4),
    );
    auto content = label("a");
    auto slot = dragSlot(content);
    auto root = testSpace(theme, slot);
    slot.handle.hide();
    root.draw();
    assert(slot.getMinSize == content.getMinSize);
    root.drawAndAssert(
        content.drawsImage(content.text.texture.chunks[0].image)
            .at(0, 0)
    );

}

@("DragSlot can be dragged")
unittest {

    auto content = label(.ignoreMouse, "a");
    auto slot = dragSlot(.nullTheme, content);
    auto hover = hoverChain();
    auto root = chain(hover, slot);

    root.draw();
    hover.point(4, 4)
        .then((a) {
            assert(a.isHovered(slot));
            assert(!slot.dragAction);
            a.press(false);
            return a.move(100, 100);
        })
        .then((a) {
            a.press(false);
            assert(a.isHovered(slot));
            assert(slot.dragAction.offset == Vector2(96, 96));
            return a.move(50, -50);
        })
        .then((a) {
            a.press(true);
            assert(slot.dragAction.offset == Vector2(46, -54));
            return root.nextFrame;
        })
        .runWhileDrawing(root);

    assert(!slot.dragAction);

}

@("DragSlot allows the dragged node to be resized while dragged")
unittest {

    auto content = resizable(Vector2(10, 10));
    auto slot = dragSlot(.nullTheme, content);
    auto hover = hoverChain();
    auto root = chain(hover, slot);

    root.draw();
    hover.point(5, 5)
        .then((a) {
            assert(a.isHovered(slot));
            assert(!slot.dragAction);
            assert(content.getMinSize == Vector2(10, 10));
            a.press(false);
            return a.move(105, 5);
        })

        // Resize the node
        .then((a) {
            a.press(false);
            content.size = Vector2(0, 0);
            content.updateSize();
            assert(slot.dragAction.offset == Vector2(100, 0));
            assert(content.getMinSize == Vector2(10, 10));
            return a.move(205, 5);
        })
        .then((a) {
            a.press(false);
            assert(slot.dragAction.offset == Vector2(200, 0));
            assert(content.getMinSize == Vector2(0, 0));
            return a.move(305, 5);
        })
        .then((a) {
            a.press(true);
            assert(slot.dragAction.offset == Vector2(300, 0));
            assert(content.getMinSize == Vector2(0, 0));
            return root.nextFrame;
        })
        .runWhileDrawing(root);

    assert(!slot.dragAction);
    assert(content.getMinSize == Vector2(0, 0));

}

@("DragSlot contents can load I/O systems while dragged")
unittest {

    static class IOTracker : Node {

        HoverIO hoverIO;
        CanvasIO canvasIO;

        override void resizeImpl(Vector2) {
            use(hoverIO);
            use(canvasIO);
        }

        override void drawImpl(Rectangle, Rectangle) {

        }

    }

    alias ioTracker = nodeBuilder!IOTracker;

    auto slot = dragSlot();
    auto hover = hoverChain(slot);
    auto root = testSpace(hover);

    root.drawAndAssert(
        hover.drawsChild(slot),
    );
    assert(slot.hoverIO.opEquals(hover));
    auto action = hover.point(0, 0);
    slot.drag(action.pointer);
    assert(slot.dragAction);
    root.drawAndAssert(
        hover.doesNotDrawChildren,
        slot.isDrawn,
    );
    assert(slot.dragAction);
    assert(slot.hoverIO.opEquals(hover));

    // Place the tracker in the slot, continue dragging
    auto tracker = ioTracker();
    slot = tracker;
    slot.drag(action.pointer);
    root.drawAndAssert(
        hover.doesNotDrawChildren,
        slot.isDrawn,
        slot.value.isDrawn,
    );
    assert(slot.dragAction);
    assert(slot.hoverIO.opEquals(hover));
    assert(slot.canvasIO.opEquals(root));
    assert(tracker.hoverIO.opEquals(hover));
    assert(tracker.canvasIO.opEquals(hover));

}
