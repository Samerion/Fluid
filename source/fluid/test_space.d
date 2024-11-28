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

    override void cropArea(Rectangle area) nothrow {

        probe.runAssert(a => a.cropArea(probe.subject, area));

    }

    override void resetCropArea() nothrow {

        probe.runAssert(a => a.resetCropArea(probe.subject));

    }

    override void drawTriangle(Vector2 x, Vector2 y, Vector2 z, Color color) nothrow {

        probe.runAssert(a => a.drawTriangle(probe.subject, x, y, z, color));

    }

    override void drawCircle(Vector2 center, float radius, Color color) nothrow {

        probe.runAssert(a => a.drawCircle(probe.subject, center, radius, color));

    }

    override void drawRectangle(Rectangle rectangle, Color color) nothrow {

        probe.runAssert(a => a.drawRectangle(probe.subject, rectangle, color));

    }

    /// Draw a single frame and test if the asserts can be fulfilled.
    void drawAndAssert(Assert[] asserts...) {

        probe.asserts = asserts.dup;
        queueAction(probe);
        draw();

    }

}

private class TestProbe : TreeAction {

    import fluid.future.stack;

    public {

        /// Subject that is currently tested.
        Node subject;

        /// Asserts that need to pass before the end of iteration/
        Assert[] asserts;

    }

    private {

        /// Node draw stack
        Stack!Node stack;

    }

    /// Check an assertion in the `asserts` queue.
    /// Params:
    ///     dg      = Function to run the assert. Returns true if the assert succeeds.
    protected void runAssert(bool delegate(Assert a) @safe nothrow dg) nothrow {

        // No tests remain
        if (asserts.empty) return;

        // Test passed, continue to the next one
        if (dg(asserts.front)) {
            nextAssert();
        }

    }

    /// Move to the next test.
    protected void nextAssert() nothrow {

        // Move to the next assert in the list
        do asserts.popFront;

        // Call `resume` on the next item. Continue while tests pass
        while (!asserts.empty && asserts.front.resume(subject));

    }

    override void beforeDraw(Node node, Rectangle space, Rectangle outer, Rectangle inner) {
        stack ~= node;
        this.subject = node;
        runAssert(a => a.beforeDraw(node, space, outer, inner));
    }

    override void afterDraw(Node node, Rectangle space, Rectangle outer, Rectangle inner) {

        stack.pop();
        runAssert(a => a.afterDraw(node, space, outer, inner));

        // Restore previous subject from the stack
        if (!stack.empty) {
            this.subject = stack.top;
        }
        else {
            this.subject = null;
        }

    }

    override void afterTree() {

        // Make sure the asserts pass
        assert(this.asserts.empty, format!"Assert[%s] failure: %s"(
            asserts.length - this.asserts.length, this.asserts.front.toString));

        // Don't iterate again
        stop();

    }

}

/// Class to test I/O calls performed by Fluid nodes. Any I/O method of `TestSpace` will call this.
/// 
/// If a tester method returns `pass` or `passNext`, the assert passes, and the next one is loaded.
/// It it returns `false`, the frame continues until all nodes are exhausted (and fails), 
/// or a matching test is found. 
///
/// `beforeDraw` or `resume` is expected to be called before any of the I/O calls.
interface Assert {

    /// After another test passes and this test is chosen, `resume` will be called to let the test
    /// know the current position in the tree. This is important in situations where `resume` is immediately
    /// followed by `beforeDraw`; the node passed to `resume` will be the parent of the one passed to `beforeDraw`.
    bool resume(Node node) nothrow;

    // Tree
    bool beforeDraw(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) nothrow;
    bool afterDraw(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) nothrow;

    // CanvasIO
    bool cropArea(Node node, Rectangle area) nothrow;
    bool resetCropArea(Node node) nothrow;
    bool drawTriangle(Node node, Vector2 a, Vector2 b, Vector2 c, Color color) nothrow;
    bool drawCircle(Node node, Vector2 center, float radius, Color color) nothrow;
    bool drawRectangle(Node node, Rectangle rectangle, Color color) nothrow;

    // Meta
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

/// Assert true if the parent requests drawing the node, 
/// but the node does not need to draw anything for the assert to succeed.
auto isDrawn(Node subject) {

    return new class BlackHole!Assert {

        override bool resume(Node node) {
            return node == subject;
        }

        override bool beforeDraw(Node node, Rectangle, Rectangle, Rectangle) {
            return node == subject;
        }

        override string toString() const {
            return format!"%s must be reached"(subject);
        }

    };

}

/// Make sure the selected node draws, but doesn't matter what.
auto draws(Node subject) {

    return drawsWildcard!((node, methodName) {

        return node == subject
            && methodName.startsWith("draw");

    })(format!"%s should draw"(subject));

}

/// Make sure the selected node doesn't draw anything until another node does.
auto doesNotDraw(Node subject) {

    bool matched;
    bool failed;

    return drawsWildcard!((node, methodName) {

        // Test failed, skip checks
        if (failed) return false;

        // Make sure the node is reached
        if (!matched) {
            if (node != subject) {
                return false;
            } 
            matched = true;
        }

        // Switching to another node
        if (methodName == "beforeDraw" && node != subject) {
            return true;
        }

        // Ending this node
        if (methodName == "afterDraw" && node == subject) {
            return true;
        }

        if (node == subject && methodName.startsWith("draw")) {
            failed = true;
            return false;
        }

        return false;

    })(matched ? format!"%s shouldn't draw"(subject)
               : format!"%s should be reached"(subject));

}

auto drawsWildcard(alias dg)(lazy string message) {

    return new class Assert {

        override bool resume(Node node) nothrow {
            return dg(node, "resume");
        }

        override bool beforeDraw(Node node, Rectangle, Rectangle, Rectangle) nothrow {
            return dg(node, "beforeDraw");
        }

        override bool afterDraw(Node node, Rectangle, Rectangle, Rectangle) nothrow {
            return dg(node, "afterDraw");
        }

        override bool cropArea(Node node, Rectangle) nothrow {
            return dg(node, "cropArea");
        }
        
        override bool resetCropArea(Node node) nothrow {
            return dg(node, "resetCropArea");
        }
        
        override bool drawTriangle(Node node, Vector2, Vector2, Vector2, Color) nothrow {
            return dg(node, "drawTriangle");
        }
        
        override bool drawCircle(Node node, Vector2, float, Color) nothrow {
            return dg(node, "drawCircle");
        }
        
        override bool drawRectangle(Node node, Rectangle, Color) nothrow {
            return dg(node, "drawRectangle");
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
@("TestSpace can perform basic tests with draws, drawsRectangle and doesNotDraw")
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

@system
@("TestProbe correctly handles node exits")
unittest {

    import fluid.label;

    static class Surround : Space {

        CanvasIO canvasIO;

        this(Node[] nodes...) @safe {
            super(nodes);
        }

        override void resizeImpl(Vector2 space) {
            super.resizeImpl(space);
            use(canvasIO);
        }

        override void drawImpl(Rectangle outer, Rectangle inner) {
            canvasIO.drawRectangle(outer, color("#a00"));
            super.drawImpl(outer, inner);
            canvasIO.drawRectangle(outer, color("#0a0"));
        }

    }

    alias surround = nodeBuilder!Surround;

    {
        auto myLabel = label("!");
        auto root = surround(
            myLabel,
        );
        auto test = testSpace(root);

        test.drawAndAssert(
            root.drawsRectangle(),
            myLabel.isDrawn(),
            root.drawsRectangle(),
        );
        assertThrown!AssertError(
            test.drawAndAssert(
                root.drawsRectangle(),
                myLabel.isDrawn(),
                root.doesNotDraw(),
            ),
        );
        assertThrown!AssertError(
            test.drawAndAssert(
                root.doesNotDraw(),
                myLabel.isDrawn(),
                root.drawsRectangle(),
            ),
        );
    }
    {
        auto myLabel = label("!");
        auto wrapper = vspace(myLabel);
        auto root = surround(
            wrapper,
        );
        auto test = testSpace(root);

        test.drawAndAssert(
            root.drawsRectangle(),
                wrapper.isDrawn(),
                wrapper.doesNotDraw(),
                    myLabel.isDrawn(),
                wrapper.doesNotDraw(),
            root.drawsRectangle(),
        );
        test.drawAndAssert(
            root.drawsRectangle(),
                wrapper.isDrawn(),
                wrapper.doesNotDraw(),
            root.drawsRectangle(),
        );
        test.drawAndAssert(
            root.drawsRectangle(),
            root.drawsRectangle(),
            root.doesNotDraw(),
        );
        test.drawAndAssert(
            root.drawsRectangle(),
            root.doesNotDraw(),
                wrapper.isDrawn(),
            root.drawsRectangle(),
            root.doesNotDraw(),
        );
    }

}
