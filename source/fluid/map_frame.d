module fluid.map_frame;

import std.conv;
import std.math;
import std.format;
import std.algorithm;

import fluid.node;
import fluid.frame;
import fluid.input;
import fluid.style;
import fluid.utils;
import fluid.actions;
import fluid.backend;


@safe:


/// Defines the direction the node is "dropped from", that is, which corner of the object will be the anchor.
/// Defaults to `start, start`, therefore, the supplied coordinate refers to the top-left of the object.
///
/// Automatic may be set to make it present common dropdown behavior — top-left by default, but will change if there
/// is overflow.
enum MapDropDirection {

    start, center, end, automatic

}

struct MapDropVector {

    MapDropDirection x, y;

}

struct MapPosition {

    Vector2 coords;
    MapDropVector drop;

    alias coords this;

}

MapDropVector dropVector()() {

    return MapDropVector.init;

}

MapDropVector dropVector(string dropXY)() {

    return dropVector!(dropXY, dropXY);

}

MapDropVector dropVector(string dropX, string dropY)() {

    enum val(string dropV) = dropV == "auto"
        ? MapDropDirection.automatic
        : dropV.to!MapDropDirection;

    return MapDropVector(val!dropX, val!dropY);

}

/// MapFrame is a frame where every child node can be placed in an arbitrary location.
///
/// MapFrame supports drag & drop.
alias mapFrame = simpleConstructor!MapFrame;

/// ditto
class MapFrame : Frame {

    alias DropDirection = MapDropDirection;
    alias DropVector = MapDropVector;
    alias Position = MapPosition;

    /// Mapping of nodes to their positions.
    Position[Node] positions;

    /// If true, the node will prevent its children from leaving the screen space.
    bool preventOverflow;

    private {

        /// Last mouse position
        Vector2 _mousePosition;

        /// Child currently dragged with the mouse.
        ///
        /// The child will move along with mouse movements performed by the user.
        Node _mouseDrag;

    }

    /// Construct the space. Arguments are either nodes, or positions/vectors affecting the next node added through
    /// the constructor.
    this(T...)(T children) {

        Position position;

        static foreach (child; children) {

            // Update position
            static if (is(typeof(child) == Position)) {

                position = child;

            }

            else static if (is(typeof(child) == MapDropVector)) {

                position.drop = child;

            }

            else static if (is(typeof(child) == Vector2)) {

                position.coords = child;

            }

            // Add child
            else {

                addChild(child, position);
                position = Position.init;

            }

        }

    }

    /// Add a new child to the space and assign it some position.
    void addChild(Node node, Position position)
    in ([position.coords.tupleof].any!isFinite, format!"Given %s isn't valid, values must be finite"(position))
    do {

        children ~= node;
        positions[node] = position;
        updateSize();
    }

    void addChild(Node node, Vector2 vector)
    in ([vector.tupleof].any!isFinite, format!"Given %s isn't valid, values must be finite"(vector))
    do {
        children ~= node;
        positions[node].coords = vector;
        updateSize();
    }

    /// ditto
    void addFocusedChild(Node node, Position position) {

        addChild(node, position);
        node.focusRecurse();

    }

    void moveChild(Node node, Position position)
    in ([position.coords.tupleof].any!isFinite, format!"Given %s isn't valid, values must be finite"(position))
    do {

        positions[node] = position;

    }

    void moveChild(Node node, Vector2 vector)
    in ([vector.tupleof].any!isFinite, format!"Given %s isn't valid, values must be finite"(vector))
    do {

        positions[node].coords = vector;

    }

    void moveChild(Node node, DropVector vector) {

        positions[node].drop = vector;

    }

    /// Make a node move relatively according to mouse position changes, making it behave as if it was being dragged by
    /// the mouse.
    Node mouseDrag(Node node) @trusted {

        assert(node in positions, "Requested node is not present in the map");

        _mouseDrag = node;
        _mousePosition = Vector2(float.nan, float.nan);

        return node;

    }

    /// Get the node currently affected by mouseDrag.
    inout(Node) mouseDrag() inout { return _mouseDrag; }

    /// Stop current mouse movements
    final void stopMouseDrag() {

        _mouseDrag = null;

    }

    /// Drag the given child, changing its position relatively.
    void dragChildBy(Node node, Vector2 delta) {

        auto position = node in positions;
        assert(position, "Dragged node is not present in the map");

        position.coords = Vector2(position.x + delta.x, position.y + delta.y);

    }

    protected override void resizeImpl(Vector2 space) {

        minSize = Vector2(0, 0);

        // TODO get rid of position entries for removed elements

        foreach (child; children) {

            const position = positions.require(child, MapPosition.init);

            child.resize(tree, theme, space);

            // Get the child's end corner
            const endCorner = getEndCorner(space, child, position);

            minSize.x = max(minSize.x, endCorner.x);
            minSize.y = max(minSize.y, endCorner.y);

        }

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        /// Move the given box to mapFrame bounds
        Vector2 moveToBounds(Vector2 coords, Vector2 size) {

            // Ignore if no overflow prevention is enabled
            if (!preventOverflow) return coords;

            return Vector2(
                coords.x.clamp(inner.x, inner.x + max(0, inner.width - size.x)),
                coords.y.clamp(inner.y, inner.y + max(0, inner.height - size.y)),
            );

        }

        // Drag the current child
        if (_mouseDrag) {

            import std.math;

            // Update the mouse position
            auto mouse = tree.io.mousePosition;
            scope (exit) _mousePosition = mouse;

            // If the previous mouse position was NaN, we've just started dragging
            if (isNaN(_mousePosition.x)) {

                // Check their current position
                auto position = _mouseDrag in positions;
                assert(position, "Dragged node is not present in the map");

                // Keep them in bounds
                position.coords = moveToBounds(position.coords, _mouseDrag.minSize);

            }

            else {

                // Drag the child
                dragChildBy(_mouseDrag, mouse - _mousePosition);

            }

        }

        foreach (child; filterChildren) {

            const position = positions.require(child, Position.init);
            const space = Vector2(inner.w, inner.h);
            const startCorner = getStartCorner(space, child, position);

            auto vec = Vector2(inner.x, inner.y) + startCorner;

            if (preventOverflow) {

                vec = moveToBounds(vec, child.minSize);

            }

            const childRect = Rectangle(
                vec.tupleof,
                child.minSize.x, child.minSize.y
            );

            // Draw the child
            child.draw(childRect);

        }

    }

    private alias getStartCorner = getCorner!false;
    private alias getEndCorner   = getCorner!true;

    private Vector2 getCorner(bool end)(Vector2 space, Node child, Position position) {

        Vector2 result;

        // Get the children's corners
        static foreach (direction; ['x', 'y']) {{

            const pos = mixin("position.coords." ~ direction);
            const dropDirection = mixin("position.drop." ~ direction);
            const childSize = mixin("child.minSize." ~ direction);

            /// Get the value
            float value(DropDirection targetDirection) {

                /// Get the direction chosen by auto.
                DropDirection autoDirection() {

                    // Check if it overflows on the end
                    const overflowEnd = pos + childSize > mixin("space." ~ direction);

                    // Drop from the start
                    if (!overflowEnd) return DropDirection.start;

                    // Check if it overflows on both sides
                    const overflowStart = pos - childSize < 0;

                    return overflowStart
                        ? DropDirection.center
                        : DropDirection.end;

                }

                static if (end)
                return targetDirection.predSwitch(
                    DropDirection.start,     pos + childSize,
                    DropDirection.center,    pos + childSize/2,
                    DropDirection.end,       pos,
                    DropDirection.automatic, value(autoDirection),
                );

                else
                return targetDirection.predSwitch(
                    DropDirection.start,     pos,
                    DropDirection.center,    pos - childSize/2,
                    DropDirection.end,       pos - childSize,
                    DropDirection.automatic, value(autoDirection),
                );

            }

            mixin("result." ~ direction) = value(dropDirection);

        }}

        return result;

    }

    unittest {

        import fluid.space;
        import fluid.structs : layout;

        class RectangleSpace : Space {

            Color color;

            this(Color color) @safe {
                this.color = color;
            }

            override void resizeImpl(Vector2) @safe {
                minSize = Vector2(10, 10);
            }

            override void drawImpl(Rectangle outer, Rectangle inner) @safe {
                io.drawRectangle(inner, color);
            }

        }

        auto io = new HeadlessBackend;
        auto root = mapFrame(
            layout!"fill",

            // Rectangles with same X and Y

            Vector2(50, 50),
            .dropVector!"start",
            new RectangleSpace(color!"f00"),

            Vector2(50, 50),
            .dropVector!"center",
            new RectangleSpace(color!"0f0"),

            Vector2(50, 50),
            .dropVector!"end",
            new RectangleSpace(color!"00f"),

            // Rectangles with different Xs

            Vector2(50, 100),
            .dropVector!("start", "start"),
            new RectangleSpace(color!"e00"),

            Vector2(50, 100),
            .dropVector!("center", "start"),
            new RectangleSpace(color!"0e0"),

            Vector2(50, 100),
            .dropVector!("end", "start"),
            new RectangleSpace(color!"00e"),

            // Overflowing rectangles
            Vector2(-10, -10),
            new RectangleSpace(color!"f0f"),

            Vector2(20, -5),
            new RectangleSpace(color!"0ff"),

            Vector2(-5, 20),
            new RectangleSpace(color!"ff0"),
        );

        root.io = io;
        root.theme = nullTheme;

        foreach (preventOverflow; [false, true, false]) {

            root.preventOverflow = preventOverflow;
            root.draw();

            // Every rectangle is attached to (50, 50) but using a different origin point
            // The first red rectangle is attached by its start corner, the green by center corner, and the blue by end
            // corner
            io.assertRectangle(Rectangle(50, 50, 10, 10), color!"f00");
            io.assertRectangle(Rectangle(45, 45, 10, 10), color!"0f0");
            io.assertRectangle(Rectangle(40, 40, 10, 10), color!"00f");

            // This is similar for the second triple of rectangles, but the Y axis is the same for every one of them
            io.assertRectangle(Rectangle(50, 100, 10, 10), color!"e00");
            io.assertRectangle(Rectangle(45, 100, 10, 10), color!"0e0");
            io.assertRectangle(Rectangle(40, 100, 10, 10), color!"00e");

            if (preventOverflow) {

                // Two rectangles overflow: one is completely outside the view, and one is only peeking in
                // With overflow disabled, they should both be moved strictly inside the mapFrame
                io.assertRectangle(Rectangle(0, 0, 10, 10), color!"f0f");
                io.assertRectangle(Rectangle(20, 0, 10, 10), color!"0ff");
                io.assertRectangle(Rectangle(0, 20, 10, 10), color!"ff0");

            }

            else {

                // With overflow enabled, these two overflows should now be allowed to stay outside
                io.assertRectangle(Rectangle(-10, -10, 10, 10), color!"f0f");
                io.assertRectangle(Rectangle(20, -5, 10, 10), color!"0ff");
                io.assertRectangle(Rectangle(-5, 20, 10, 10), color!"ff0");

            }

        }

    }

    override void dropHover(Vector2 position, Rectangle rectangle) {

    }

    override void drop(Vector2, Rectangle rectangle, Node node) {

        const position = MapPosition(rectangle.start);

        // Already a child
        if (children.canFind(node)) {

            positions[node] = position;

        }

        // New child
        else this.addChild(node, position);

    }

}
