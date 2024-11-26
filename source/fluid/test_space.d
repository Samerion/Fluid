module fluid.test_space;

version (Fluid_TestSpace):

debug (Fluid_BuildMessages) {
    pragma(msg, "Fluid: Including TestSpace");
}

import core.exception;

import std.conv : toText = text;
import std.range;
import std.string;
import std.typecons;
import std.exception;

import fluid.node;
import fluid.tree;
import fluid.utils;
import fluid.space;
import fluid.input;
import fluid.backend;

import fluid.io.canvas;

@safe:

alias testSpace = nodeBuilder!TestSpace;

/// This node allows automatically testing if other nodes draw their contents as expected.
class TestSpace : Space, CanvasIO {

    private {

        /// Asserts that need to be fulfilled during the next frame.
        Assert[] asserts;

        /// Probe the space will use to analyze the tree.
        TestProbe probe;

    }

    this(Node[] nodes...) {

        super(nodes);

        // Create a probe for testing.
        this.probe = new TestProbe();

    }

    override void resizeImpl(Vector2 space) {

        auto frame = this.implementIO();

        super.resizeImpl(space);

    }

    void runAssert(bool delegate(Assert a) @safe nothrow dg) nothrow {

        while (!asserts.empty) {

            const result = dg(asserts.front);

            // Test passed, try next one
            if (result) asserts.popFront;

            // Failed, try next node
            else break;

        }

    }

    override void cropArea(Rectangle area) nothrow {

        runAssert(a => a.cropArea(probe.subject, area));

    }

    override void resetCropArea() nothrow {

        runAssert(a => a.resetCropArea(probe.subject));

    }

    override void drawTriangle(Vector2 x, Vector2 y, Vector2 z, Color color) nothrow {

        runAssert(a => a.drawTriangle(probe.subject, x, y, z, color));

    }

    override void drawCircle(Vector2 center, float radius, Color color) nothrow {

        runAssert(a => a.drawCircle(probe.subject, center, radius, color));

    }

    override void drawRectangle(Rectangle rectangle, Color color) nothrow {

        runAssert(a => a.drawRectangle(probe.subject, rectangle, color));

    }

    /// Draw a single frame and test if the asserts can be fulfilled.
    void drawAndAssert(Assert[] asserts...) {

        this.asserts = asserts.dup;
        this.queueAction(probe);
        draw();
        assert(this.asserts.empty, format!"Assert[%s] failure: %s"(
            asserts.length - this.asserts.length, this.asserts.front.toString));

    }

}

private class TestProbe : TreeAction {

    Node subject;

    override void beforeDraw(Node node, Rectangle) {
        this.subject = node;
    }

}

/// Class to test I/O calls performed by Fluid nodes. Any I/O method of `TestSpace` will call this.
/// 
/// If a tester method returns `true`, the assert passes, and the next one is loaded.
/// It it returns `false`, the frame continues until all nodes are exhausted (and fails), 
/// or a matching test is found.
interface Assert {

    bool cropArea(Node node, Rectangle area) nothrow;
    bool resetCropArea(Node node) nothrow;
    bool drawTriangle(Node node, Vector2 a, Vector2 b, Vector2 c, Color color) nothrow;
    bool drawCircle(Node node, Vector2 center, float radius, Color color) nothrow;
    bool drawRectangle(Node node, Rectangle rectangle, Color color) nothrow;
    string toString() const;

}

///
auto drawsRectangle(Node subject, typeof(Rectangle.tupleof) rectangle) {
    return drawsRectangle(subject, Rectangle(rectangle));
}

/// ditto
auto drawsRectangle(Node subject, Rectangle rectangle) {
    auto result = drawsRectangle(subject);
    result.isTestingArea = true;
    result.targetArea = rectangle;
    return result;
}

auto drawsRectangle(Node subject) {

    return new class BlackHole!Assert {

        bool isTestingArea;
        Rectangle targetArea;
        bool isTestingColor;
        Color targetColor;

        override bool drawRectangle(Node node, Rectangle rect, Color color) nothrow {

            if (node != subject) return false;

            if (isTestingArea) {
                assert(equal(targetArea.x, rect.x));
                assert(equal(targetArea.y, rect.y));
                assert(equal(targetArea.width, rect.width));
                assert(equal(targetArea.height, rect.height));
            }

            if (isTestingColor) {
                assert(color == targetColor);
            }

            return true;

        }

        typeof(this) ofColor(string color) {
            return ofColor(.color(color));
        }

        typeof(this) ofColor(Color color) {
            isTestingColor = true;
            targetColor = color;
            return this;
        }

        override string toString() const {
            return toText(
                subject, " should draw a rectangle",
                isTestingArea  ? toText(" ", targetArea)                 : "",
                isTestingColor ? toText(" of color ", targetColor.toHex) : "",
            );
        }

    };

}

/// Make sure the selected node draws, but doesn't matter what.
auto draws(Node subject) {

    return drawsWildcard!((node) {
        return node == subject;
    })(format!"%s should draw"(subject));

}

/// Make sure the selected node doesn't draw anything until another node does.
auto doesNotDraw(Node subject) {

    return drawsWildcard!((node) {
        assert(node != subject);
        return true;
    })(format!"%s shouldn't draw"(subject));

}

auto drawsWildcard(alias dg)(lazy string message) {

    return new class Assert {

        override bool cropArea(Node node, Rectangle) nothrow {
            return dg(node);
        }
        
        override bool resetCropArea(Node node) nothrow {
            return dg(node);
        }
        
        override bool drawTriangle(Node node, Vector2, Vector2, Vector2, Color) nothrow {
            return dg(node);
        }
        
        override bool drawCircle(Node node, Vector2, float, Color) nothrow {
            return dg(node);
        }
        
        override bool drawRectangle(Node node, Rectangle, Color) nothrow {
            return dg(node);
        }

        override string toString() const {
            return message;
        }
        
    };

}

bool equal(float a, float b) nothrow {

    const diff = a - b;

    return diff >= -0.01
        && diff <= +0.01;

}

@system
@("`TestSpace` can perform basic tests with `draws`, `drawsRectangle` and `doesNotDraw`")
unittest {

    class MyNode : Node {

        CanvasIO canvasIO;
        auto targetRectangle = Rectangle(0, 0, 10, 10);

        override void resizeImpl(Vector2) {
            require(canvasIO);
        }

        override void drawImpl(Rectangle, Rectangle) {
            canvasIO.drawRectangle(targetRectangle, color("#f00"));
            targetRectangle.x += 1;
        }

    }

    auto myNode = new MyNode;
    auto space = testSpace(myNode);
    space.drawAndAssert(
        space.doesNotDraw(),
        myNode.drawsRectangle(0, 0, 10, 10),
    );
    space.drawAndAssert(
        space.doesNotDraw(),
        myNode.drawsRectangle(1, 0, 10, 10),
    );
    space.drawAndAssert(
        space.doesNotDraw(),
        myNode.drawsRectangle(2, 0, 10, 10).ofColor("#f00"),
    );
    space.drawAndAssert(
        space.doesNotDraw(),
        myNode.draws(),
    );
    assertThrown!AssertError(
        space.drawAndAssert(
            space.draws(),
        ),
    );
    assertThrown!AssertError(
        space.drawAndAssert(
            myNode.doesNotDraw()
        ),
    );
    space.drawAndAssert(
        myNode.drawsRectangle(),
    );
    space.drawAndAssert(
        myNode.drawsRectangle().ofColor("#f00"),
    );
    assertThrown!AssertError(
        space.drawAndAssert(
            myNode.drawsRectangle().ofColor("#500"),
        ),
    );
    assertThrown!AssertError(
        space.drawAndAssert(
            space.drawsRectangle().ofColor("#500"),
        ),
    );

}
