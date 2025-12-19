module actions.find_hovered_node_action;

import fluid;

@safe:

alias rectangleBox = nodeBuilder!RectangleBox;

class RectangleBox : Node {

    Rectangle self;

    this(Rectangle self) {
        this.self = self;
    }

    override void resizeImpl(Vector2) {
        minSize = Vector2(0, 0);
    }

    override void drawImpl(Rectangle, Rectangle) {

    }

    override HitFilter inBoundsImpl(Rectangle, Rectangle, Vector2 position) {
        return self.contains(position)
            ? HitFilter.hit
            : HitFilter.miss;
    }

}

alias circleBox = nodeBuilder!CircleBox;

class CircleBox : Node {

    Vector2 center;
    float radius;

    this(Vector2 center, float radius) {
        this.center = center;
        this.radius = radius;
    }

    override void resizeImpl(Vector2) {
        minSize = Vector2(0, 0);
    }

    override void drawImpl(Rectangle, Rectangle) {

    }

    override HitFilter inBoundsImpl(Rectangle, Rectangle, Vector2 position) {
        return (center.x - position.x)^^2 + (center.y - position.y)^^2 <= radius^^2
            ? HitFilter.hit
            : HitFilter.miss;
    }

}

alias myScrollable = nodeBuilder!MyScrollable;

class MyScrollable : Frame, HoverScrollable {

    bool disableScroll;

    this(Node[] nodes...) {
        super(nodes);
    }

    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

    override bool canScroll(const HoverPointer) const {
        return !disableScroll;
    }

    override bool scrollImpl(HoverPointer) {
        return true;
    }

    override Rectangle shallowScrollTo(const Node, Rectangle, Rectangle childBox) {
        return childBox;
    }

}

alias weight = nodeBuilder!Weight;

class Weight : Node {

    override void resizeImpl(Vector2) {
        minSize = Vector2(400, 400);
    }

    override void drawImpl(Rectangle, Rectangle) {

    }

}

@("FindHoveredNodeAction can find any node by screen position")
unittest {

    Node rect1, rect2, circle;

    auto root = onionFrame(
        rect1  = rectangleBox(Rectangle(0, 0, 50, 50)),
        rect2  = rectangleBox(Rectangle(50, 50, 50, 50)),
        circle = circleBox(Vector2(50, 50), 10),
    );
    auto action = new FindHoveredNodeAction;

    action.pointer.position = Vector2(0, 0);
    root.startAction(action);
    root.draw();
    assert(action.result.opEquals(rect1));

    action.pointer.position = Vector2(60, 0);
    root.startAction(action);
    root.draw();
    assert(action.result is null);

    action.pointer.position = Vector2(60, 50);
    root.startAction(action);
    root.draw();
    assert(action.result.opEquals(circle));

    action.pointer.position = Vector2(75, 75);
    root.startAction(action);
    root.draw();
    assert(action.result.opEquals(rect2));

}

@("FindHoveredNodeAction can find scrollable ancestors of any node")
unittest {

    Button buttonIn, buttonOut;
    ScrollFrame scroll;

    auto root = sizeLock!hspace(
        .sizeLimit(100, 100),
        .nullTheme,
        scroll = vscrollFrame(
            .layout!(1, "fill"),
            buttonIn = sizeLock!button(
                .sizeLimit(50, 100),
                "In scrollable 1",
                delegate { }
            ),
            sizeLock!button(
                .sizeLimit(50, 100),
                "In scrollable 2",
                delegate { }
            ),
        ),
        buttonOut = button(
            .layout!(1, "fill"),
            "Outside",
            delegate { }
        ),
    );
    auto action = new FindHoveredNodeAction;
    assert(root.isHorizontal);

    action.pointer.position = Vector2(25, 50);
    action.pointer.scroll = Vector2(0, 10);
    root.startAction(action);
    root.draw();
    assert(action.result.opEquals(buttonIn));
    assert(action.scrollable.opEquals(scroll));

    action.pointer.position = Vector2(75, 50);
    root.startAction(action);
    root.draw();
    assert(action.result.opEquals(buttonOut));
    assert(action.scrollable is null);

}

@("FindHoveredNodeAction skips over Scrollables where scroll will have no effect")
unittest {

    MyScrollable outer, inner;

    auto root = sizeLock!vframe(
        .sizeLimit(100, 100),
        outer = myScrollable(
            .layout!(1, "fill"),
            inner = myScrollable(
                .layout!(1, "fill"),
            ),
        ),
    );
    auto action = new FindHoveredNodeAction;

    action.pointer.position = Vector2(50, 50);
    action.pointer.scroll = Vector2(0, 10);
    root.startAction(action);
    root.draw();
    assert(action.result.opEquals(inner));
    assert(action.scrollable.opEquals(inner));

    inner.disableScroll = true;
    root.startAction(action);
    root.draw();
    assert(action.result.opEquals(inner));
    assert(action.scrollable.opEquals(outer));

}

@("FindHoveredNodeAction respects Node.isOpaque")
unittest {

    import std.conv;

    Frame container;
    RectangleBox[3] boxes;

    auto root = sizeLock!vspace(
        .sizeLimit(50, 150),
        container = vframe(
            .layout!(1, "fill"),
            boxes[0] = rectangleBox(                     Rectangle(0,   0, 50, 50)),
            boxes[1] = rectangleBox(HitFilter.miss,      Rectangle(0,  50, 50, 50)),
            boxes[2] = rectangleBox(HitFilter.hitBranch, Rectangle(0, 100, 50, 50)),
        ),
    );

    auto action = new FindHoveredNodeAction;

    void testSearch(HitFilter filter, Vector2 position, Node result) {
        container.hitFilter = filter;
        action.pointer.position = position;
        root.startAction(action);
        root.draw();
        if (result is null) {
            assert(action.result is null, action.result.text);
        }
        else {
            assert(result.opEquals(action.result), action.result.text);
        }
    }

    // Children should be selectable for both `hit` and `miss` options
    testSearch(HitFilter.hit, Vector2(25,  25), boxes[0]);
    testSearch(HitFilter.hit, Vector2(25, 125), boxes[2]);

    // `miss` on boxes[1] prevents from selecting
    testSearch(HitFilter.hit,  Vector2(25, 75), container);
    testSearch(HitFilter.miss, Vector2(25, 75), null);

    // The remaining options disable children access
    testSearch(HitFilter.missBranch, Vector2(25, 25), null);
    testSearch(HitFilter.hitBranch,  Vector2(25, 25), container);

}

@("Scrollables are located correctly among nodes with HitFilter.hitBranch")
unittest {
    // https://git.samerion.com/Samerion/Fluid/issues/482
    // As a bug, finding a scrollable before hitBranch prevented the branch from ending

    ScrollFrame firstFrame;
    ScrollFrame secondFrame;

    auto root = sizeLock!onionFrame(
        .sizeLimit(100, 100),

        // Bug condition:
        firstFrame = vscrollFrame(
            .layout!"fill",
            weight(),
        ),
        vframe(
            .layout!"fill",
            .HitFilter.missBranch,
        ),

        // Check:
        secondFrame = vscrollFrame(
            .layout!"fill",
            weight(),
        ),
    );

    auto action = new FindHoveredNodeAction;
    action.pointer.position = Vector2(50, 50);
    action.pointer.scroll = Vector2(0, 50);
    root.startAction(action);
    root.draw();

    // Condition:
    assert(firstFrame.canScroll(action.pointer.scroll));
    assert(secondFrame.canScroll(action.pointer.scroll));

    // Check
    assert(action.scrollable !is firstFrame);
    assert(action.scrollable  is secondFrame);

}
