module glui.map_space;

import raylib;

import std.conv;
import std.math;
import std.format;
import std.algorithm;

import glui.node;
import glui.input;
import glui.space;
import glui.style;
import glui.utils;
import glui.actions;
import glui.container;


@safe:


alias mapSpace = simpleConstructor!GluiMapSpace;

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

class GluiMapSpace : GluiSpace {

    mixin DefineStyles;

    alias DropDirection = MapDropDirection;
    alias DropVector = MapDropVector;
    alias Position = MapPosition;

    /// Mapping of nodes to their positions.
    Position[GluiNode] positions;

    /// If true, the node will prevent its children from leaving the screen space.
    bool preventOverflow;

    deprecated("preventOverlap has been renamed to preventOverflow and will be removed in Glui 0.6.0")
    ref inout(bool) preventOverlap() inout { return preventOverflow; }

    private {

        /// Last mouse position
        Vector2 _mousePosition;

        /// Child currently dragged with the mouse.
        ///
        /// The child will move along with mouse movements performed by the user.
        GluiNode _mouseDrag;

    }

    static foreach (index; 0..BasicNodeParamLength) {

        /// Construct the space. Arguments are either nodes, or positions/vectors affecting the next node added through
        /// the constructor.
        this(T...)(BasicNodeParam!index params, T children)
        if (!T.length || is(T[0] == Vector2) || is(T[0] == DropVector) || is(T[0] == Position) || is(T[0] : GluiNode)) {

            super(params);

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

    }

    /// Add a new child to the space and assign it some position.
    void addChild(GluiNode node, Position position)
    in ([position.coords.tupleof].any!isFinite, format!"Given %s isn't valid, values must be finite"(position))
    do {

        children ~= node;
        positions[node] = position;
        updateSize();
    }

    /// ditto
    void addFocusedChild(GluiNode node, Position position) {

        addChild(node, position);
        node.focusRecurse();

    }

    void moveChild(GluiNode node, Position position)
    in ([position.coords.tupleof].any!isFinite, format!"Given %s isn't valid, values must be finite"(position))
    do {

        positions[node] = position;

    }

    void moveChild(GluiNode node, Vector2 vector)
    in ([vector.tupleof].any!isFinite, format!"Given %s isn't valid, values must be finite"(vector))
    do {

        positions[node].coords = vector;

    }

    void moveChild(GluiNode node, DropVector vector) {

        positions[node].drop = vector;

    }

    /// Make a node move relatively according to mouse position changes, making it behave as if it was being dragged by
    /// the mouse.
    GluiNode mouseDrag(GluiNode node) @trusted {

        assert(node in positions, "Requested node is not present in the map");

        _mouseDrag = node;
        _mousePosition = Vector2(float.nan, float.nan);

        return node;

    }

    /// Get the node currently affected by mouseDrag.
    inout(GluiNode) mouseDrag() inout { return _mouseDrag; }

    /// Stop current mouse movements
    final void stopMouseDrag() {

        _mouseDrag = null;

    }

    /// Drag the given child, changing its position relatively.
    void dragChildBy(GluiNode node, Vector2 delta) {

        auto position = node in positions;
        assert(position, "Dragged node is not present in the map");

        position.coords = Vector2(position.x + delta.x, position.y + delta.y);

    }

    protected override void resizeImpl(Vector2 space) {

        minSize = Vector2(0, 0);

        // TODO get rid of position entries for removed elements

        foreach (child; children) {

            const position = positions[child];

            child.resize(tree, theme, space);

            // Get the child's end corner
            const endCorner = getEndCorner(space, child, position);

            minSize.x = max(minSize.x, endCorner.x);
            minSize.y = max(minSize.y, endCorner.y);

        }

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        /// Move the given box to mapSpace bounds
        Vector2 moveToBounds(Vector2 coords, Vector2 size) {

            // Ignore if no overflow prevention is enabled
            if (!preventOverflow) return coords;

            return Vector2(
                coords.x.clamp(inner.x, inner.x + max(0, inner.width - size.x)),
                coords.y.clamp(inner.y, inner.y + max(0, inner.height - size.y)),
            );

        }

        // Drag the current child
        if (_mouseDrag) () @trusted {

            import std.math;

            // Update the mouse position
            auto mouse = GetMousePosition();
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

        }();

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

    private Vector2 getCorner(bool end)(Vector2 space, GluiNode child, Position position) {

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

}
