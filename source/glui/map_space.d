module glui.map_space;

import raylib;

import std.conv;
import std.algorithm;

import glui.node;
import glui.space;
import glui.style;
import glui.utils;


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
    bool preventOverlap;

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
    void addChild(GluiNode node, Position position) {

        children ~= node;
        positions[node] = position;
        updateSize();

    }

    void moveChild(GluiNode node, Position position) {

        positions[node] = position;

    }

    void moveChild(GluiNode node, Vector2 vector) {

        positions[node].coords = vector;

    }

    void moveChild(GluiNode node, DropVector vector) {

        positions[node].drop = vector;

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

        drawChildren((child) {

            const position = positions.require(child, Position.init);
            const space = Vector2(inner.w, inner.h);
            const startCorner = getStartCorner(space, child, position);

            auto x = inner.x + startCorner.x;
            auto y = inner.y + startCorner.y;

            if (preventOverlap) {

                x = x.clamp(inner.x, inner.x + inner.w - child.minSize.x);
                y = y.clamp(inner.y, inner.y + inner.h - child.minSize.y);

            }

            const childRect = Rectangle(
                x, y,
                child.minSize.x, child.minSize.y
            );

            // Draw the child
            child.draw(childRect);

        });

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

            const overflow = pos + childSize > mixin("space." ~ direction);

            static if (end)
            mixin("result." ~ direction) = dropDirection.predSwitch(
                DropDirection.start,     pos + childSize,
                DropDirection.center,    pos + childSize/2,
                DropDirection.end,       pos,
                DropDirection.automatic, overflow ? pos : pos + childSize,
            );

            else
            mixin("result." ~ direction) = dropDirection.predSwitch(
                DropDirection.start,     pos,
                DropDirection.center,    pos - childSize/2,
                DropDirection.end,       pos - childSize,
                DropDirection.automatic, overflow ? pos - childSize : pos,
            );

        }}

        return result;

    }

}
