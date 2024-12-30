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

    override bool inBoundsImpl(Rectangle, Rectangle, Vector2 position) {
        return self.contains(position);
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

    override bool inBoundsImpl(Rectangle, Rectangle, Vector2 position) {
        return (center.x - position.x)^^2 + (center.y - position.y)^^2 <= radius^^2;
    }

}

alias myScrollable = nodeBuilder!MyScrollable;

class MyScrollable : Frame, HoverScrollable {

    bool disableScroll;

    this(Node[] nodes...) {
        super(nodes);
    }

    alias opEquals = Space.opEquals;
    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

    override bool canScroll(Vector2 value) const {
        return !disableScroll;
    }

    override void scrollImpl(Vector2) { }
    override Rectangle shallowScrollTo(const Node, Rectangle, Rectangle childBox) {
        return childBox;
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

    action.search = Vector2(0, 0);
    root.startAction(action);
    root.draw();
    assert(action.result == rect1);

    action.search = Vector2(60, 0);
    root.startAction(action);
    root.draw();
    assert(action.result is null);

    action.search = Vector2(60, 50);
    root.startAction(action);
    root.draw();
    assert(action.result == circle);

    action.search = Vector2(75, 75);
    root.startAction(action);
    root.draw();
    assert(action.result == rect2);

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

    action.search = Vector2(25, 50);
    action.scroll = Vector2(0, 10);
    root.startAction(action);
    root.draw();
    assert(action.result.opEquals(buttonIn));
    assert(action.scrollable.opEquals(scroll));

    action.search = Vector2(75, 50);
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

    action.search = Vector2(50, 50);
    action.scroll = Vector2(0, 10);
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
