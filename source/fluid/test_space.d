module fluid.test_space;

version (Fluid_TestSpace):

debug (Fluid_BuildMessages) {
    pragma(msg, "Fluid: Including TestSpace");
}

import core.exception;

import optional;

import std.conv : toText = text;
import std.range;
import std.string;
import std.typecons;
import std.algorithm;
import std.exception;

import fluid.node;
import fluid.tree;
import fluid.utils;
import fluid.space;
import fluid.input;
import fluid.backend;

import fluid.io.canvas;
import fluid.io.debug_signal;

import fluid.future.pipe;
import fluid.future.arena;

@safe:

alias testSpace = nodeBuilder!TestSpace;
alias vtestSpace = nodeBuilder!TestSpace;
alias htestSpace = nodeBuilder!(TestSpace, (a) {
    a.isHorizontal = true;
});

/// This node allows automatically testing if other nodes draw their contents as expected.
class TestSpace : Space, CanvasIO, DebugSignalIO {

    // TODO DPI tests

    private {

        /// Probe the space will use to analyze the tree.
        TestProbe _probe;

        /// Current crop area.
        Optional!Rectangle _cropArea;

        /// Current DPI.
        Vector2 _dpi = Vector2(96, 96);

        /// All presently loaded images.
        ResourceArena!Image _loadedImages;

        /// Map of image pointers (image.data.ptr) to indices in the resource arena
        int[size_t] _imageIndices;

        /// Track number of debug signals received per signal name.
        int[string] _debugSignals;

    }

    this(Node[] nodes...) {

        super(nodes);

        // Create a probe for testing.
        this._probe = new TestProbe();

    }

    /// Returns: True if the given image is loaded.
    /// Params:
    ///     image = Image to check.
    bool isImageLoaded(DrawableImage image) nothrow {

        const ptr = cast(size_t) image.data.ptr;

        // Image is registered and up to date, OK
        if (auto index = ptr in _imageIndices) {
            return *index == image.id
                && _loadedImages.isActive(*index);
        }

        // Not loaded
        return false;

    }

    /// Returns: The number of images registered by the test runner.
    int countLoadedImages() nothrow const {

        return cast(int) _loadedImages.activeResources.walkLength;

    }

    override void resizeImpl(Vector2 space) {

        auto frame = this.implementIO();

        // Free resources
        _loadedImages.startCycle((newIndex, ref image) {

            const id = cast(size_t) image.data.ptr;

            if (newIndex == -1) {
                _imageIndices.remove(id);
            }
            else {
                _imageIndices[id] = newIndex;
            }

        });

        // Resize contents
        super.resizeImpl(space);

    }

    override Vector2 dpi() const nothrow {
        return _dpi;
    }

    Vector2 dpi(Vector2 value) {
        _dpi = value;
        updateSize();
        return value;
    }

    /// Returns:
    ///     The number of times a debug signal has been emitted.
    /// Params:
    ///     name = Name of the debug signal.
    int emitCount(string name) const {

        return _debugSignals.get(name, 0);

    }

    override Optional!Rectangle cropArea() const nothrow {

        return _cropArea;

    }

    override void emitSignal(string name) nothrow {

        assertNotThrown(_debugSignals.require(name, 0)++);
        _probe.runAssert(a => a.emitSignal(_probe.subject, name));

    }

    override void cropArea(Rectangle area) nothrow {

        _probe.runAssert(a => a.cropArea(_probe.subject, area));
        _cropArea = area;

    }

    override void resetCropArea() nothrow {

        _probe.runAssert(a => a.resetCropArea(_probe.subject));
        _cropArea = none;

    }

    override void drawTriangleImpl(Vector2 x, Vector2 y, Vector2 z, Color color) nothrow {

        _probe.runAssert(a => a.drawTriangle(_probe.subject, x, y, z, color));

    }

    override void drawCircleImpl(Vector2 center, float radius, Color color) nothrow {

        _probe.runAssert(a => a.drawCircle(_probe.subject, center, radius, color));

    }

    override void drawRectangleImpl(Rectangle rectangle, Color color) nothrow {

        _probe.runAssert(a => a.drawRectangle(_probe.subject, rectangle, color));

    }

    override void drawLineImpl(Vector2 start, Vector2 end, float width, Color color) nothrow {

        _probe.runAssert(a => a.drawLine(_probe.subject, start, end, width, color));

    }

    override void drawImageImpl(DrawableImage image, Rectangle destination, Color tint) nothrow {

        assert(
            isImageLoaded(image),
            "Trying to draw an image without loading");

        _probe.runAssert(a => a.drawImage(_probe.subject, image, destination, tint));

    }

    override void drawHintedImageImpl(DrawableImage image, Rectangle destination, Color tint) nothrow {

        assert(
            isImageLoaded(image),
            "Trying to draw an image without loading");

        _probe.runAssert(a => a.drawHintedImage(_probe.subject, image, destination, tint));

    }

    override int load(Image image) nothrow {

        const ptr = cast(size_t) image.data.ptr;

        // If the image is already loaded, mark it as so
        if (auto index = ptr in _imageIndices) {
            _loadedImages.reload(*index, image);
            return *index;
        }

        // If not, add it
        else {
            return _imageIndices[ptr] = _loadedImages.load(image);
        }

    }

    /// Draw a single frame and test if the asserts can be fulfilled.
    void drawAndAssert(Assert[] asserts...) {

        _probe.asserts = asserts.dup;
        queueAction(_probe);
        draw();

    }

    /// Draw a single frame and make sure the asserts are NOT fulfilled.
    void drawAndAssertFailure(Assert[] asserts...) @trusted {

        assertThrown!AssertError(
            drawAndAssert(asserts)
        );

    }

}

private class TestProbe : TreeAction {

    import fluid.future.stack;

    public {

        /// Subject that is currently tested.
        Node subject;

        /// Asserts that need to pass before the end of iteration. Asserts that pass are popped off this array.
        Assert[] asserts;

        /// Number of asserts that passed since start of iteration.
        int assertsPassed;

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
        do {
            asserts.popFront;
            assertsPassed++;
        }

        // Call `resume` on the next item. Continue while tests pass
        while (!asserts.empty && asserts.front.resume(subject));

    }

    override void started() {

        // Reset pass count
        assertsPassed = 0;

    }

    override void beforeResize(Node node, Vector2) {
        stack ~= node;
        this.subject = node;
    }

    override void afterResize(Node node, Vector2) {
        stack.pop();

        // Restore previous subject from the stack
        if (!stack.empty) {
            this.subject = stack.top;
        }
        else {
            this.subject = null;
        }
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

    override void stopped() {

        // Make sure the asserts pass
        assert(this.asserts.empty, format!"Assert[%s] failure: %s"(
            assertsPassed, this.asserts.front.toString));

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

    // DebugSignalIO
    bool emitSignal(Node node, string name) nothrow;

    // CanvasIO
    bool cropArea(Node node, Rectangle area) nothrow;
    bool resetCropArea(Node node) nothrow;
    bool drawTriangle(Node node, Vector2 a, Vector2 b, Vector2 c, Color color) nothrow;
    bool drawCircle(Node node, Vector2 center, float radius, Color color) nothrow;
    bool drawRectangle(Node node, Rectangle rectangle, Color color) nothrow;
    bool drawLine(Node node, Vector2 start, Vector2 end, float width, Color color) nothrow;
    bool drawImage(Node node, DrawableImage image, Rectangle destination, Color tint) nothrow;
    bool drawHintedImage(Node node, DrawableImage image, Rectangle destination, Color tint) nothrow;

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

            // node != subject MAY throw
            if (!node.opEquals(subject).assertNotThrown) return false;

            if (isTestingArea) {
                if (!equal(targetArea.x, rect.x)
                    || !equal(targetArea.y, rect.y)
                    || !equal(targetArea.width, rect.width)
                    || !equal(targetArea.height, rect.height)) return false;
            }

            if (isTestingColor) {
                if (color != targetColor) return false;
            }

            return true;

        }

        typeof(this) ofColor(string color) @safe {
            return ofColor(.color(color));
        }

        typeof(this) ofColor(Color color) @safe {
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

/// Test if the subject draws a line.
auto drawsLine(Node subject) {

    return new class BlackHole!Assert {

        bool isTestingStart;
        Vector2 targetStart;
        bool isTestingEnd;
        Vector2 targetEnd;
        bool isTestingWidth;
        float targetWidth;
        bool isTestingColor;
        Color targetColor;

        override bool drawLine(Node node, Vector2 start, Vector2 end, float width, Color color) nothrow {

            // node != subject MAY throw
            if (!node.opEquals(subject).assertNotThrown) return false;

            if (isTestingStart) {
                assert(equal(targetStart.x, start.x)
                    && equal(targetStart.y, start.y),
                    format!"Expected start %s, got %s"(targetStart, start).assertNotThrown);
            }

            if (isTestingEnd) {
                assert(equal(targetEnd.x, end.x)
                    && equal(targetEnd.y, end.y),
                    format!"Expected end %s, got %s"(targetEnd, end).assertNotThrown);
            }

            if (isTestingWidth) {
                assert(equal(targetWidth, width),
                    format!"Expected width %s, got %s"(targetWidth, width).assertNotThrown);
            }

            if (isTestingColor) {
                assert(targetColor == color,
                    format!"Expected color %s, got %s"(targetColor, color).assertNotThrown);
            }

            return true;

        }

        typeof(this) from(float x, float y) @safe {
            return from(Vector2(x, y));
        }

        typeof(this) from(Vector2 start) @safe {
            isTestingStart = true;
            targetStart = start;
            return this;
        }

        typeof(this) to(float x, float y) @safe {
            return to(Vector2(x, y));
        }

        typeof(this) to(Vector2 end) @safe {
            isTestingEnd = true;
            targetEnd = end;
            return this;
        }

        typeof(this) ofWidth(float width) @safe {
            isTestingWidth = true;
            targetWidth = width;
            return this;
        }

        typeof(this) ofColor(string color) @safe {
            return ofColor(.color(color));
        }

        typeof(this) ofColor(Color color) @safe {
            isTestingColor = true;
            targetColor = color;
            return this;
        }

        override string toString() const {
            return toText(
                subject, " should draw a line",
                isTestingStart ? toText(" from ", targetStart)           : "",
                isTestingEnd   ? toText(" to ", targetEnd)               : "",
                isTestingWidth ? toText(" of width ", targetWidth)       : "",
                isTestingColor ? toText(" of color ", targetColor.toHex) : "",
            );
        }

    };

}

/// Params:
///     subject = Test if this subject draws an image.
/// Returns:
///     An `Assert` that can be passed to `TestSpace.drawAndAssert` to test if a node draws an image.
auto drawsImage(Node subject, Image image) {

    auto test = drawsImage(subject);
    test.isTestingImage = true;
    test.targetImage = image;
    test.isTestingColor = true;
    test.targetColor = color("#fff");
    return test;

}

/// ditto
auto drawsHintedImage(Node subject, Image image) {

    auto test = drawsImage(subject, image);
    test.isTestingHint = true;
    test.targetHint = true;
    return test;

}

/// ditto
auto drawsImage(Node subject) {

    return new class BlackHole!Assert {

        bool isTestingImage;
        Image targetImage;
        bool isTestingArea;
        Rectangle targetArea;
        bool isTestingColor;
        Color targetColor;
        bool isTestingHint;
        bool targetHint;
        bool isTestingPalette;
        Color[] targetPalette;

        override bool drawImage(Node node, DrawableImage image, Rectangle rect, Color color) nothrow {

            if (!node.opEquals(subject).assertNotThrown) return false;

            if (isTestingImage) {
                const bothEmpty = image.data.empty && targetImage.data.empty;
                assert(image.format == targetImage.format);
                assert(bothEmpty || image.data is targetImage.data,
                    format!"%s should draw image 0x%02x but draws 0x%02x"(
                        node, cast(size_t) targetImage.data.ptr, cast(size_t) image.data.ptr).assertNotThrown);

                if (isTestingPalette) {
                    assert(image.format == Image.Format.palettedAlpha);
                    assert(image.palette == targetPalette,
                        format!"%s should draw image with palette %s but uses %s"(
                            node, targetPalette.map!(a => a.toHex), image.palette.map!(a => a.toHex))
                            .assertNotThrown);
                }
            }

            if (isTestingArea) {
                assert(equal(targetArea.x, rect.x)
                    && equal(targetArea.y, rect.y)
                    && equal(targetArea.width, rect.width)
                    && equal(targetArea.height, rect.height),
                    format!"%s should draw image at %s, but draws at %s"(node, targetArea, rect).assertNotThrown);
            }

            if (isTestingColor) {
                assert(color == targetColor);
            }

            if (isTestingHint) {
                assert(!targetHint);
            }

            return true;

        }

        override bool drawHintedImage(Node node, DrawableImage image, Rectangle rect, Color color) nothrow {

            targetHint = false;
            scope (exit) targetHint = true;

            return drawImage(node, image, rect, color);

        }

        typeof(this) at(Vector2 position) @safe {
            isTestingArea = true;
            targetArea = Rectangle(position.tupleof, targetImage.size.tupleof);
            // TODO DPI
            return this;

        }

        typeof(this) at(typeof(Vector2.tupleof) position) @safe {
            isTestingArea = true;
            targetArea = Rectangle(position, targetImage.size.tupleof);
            // TODO DPI
            return this;
        }

        typeof(this) at(Rectangle area) @safe {
            isTestingArea = true;
            targetArea = area;
            // TODO DPI
            return this;

        }

        typeof(this) at(typeof(Rectangle.tupleof) position) @safe {
            isTestingArea = true;
            targetArea = Rectangle(position);
            // TODO DPI
            return this;
        }

        typeof(this) withPalette(Color[] colors...) @safe {
            isTestingPalette = true;
            targetPalette = colors.dup;
            return this;
        }

        typeof(this) ofColor(string color) @safe {
            return ofColor(.color(color));
        }

        typeof(this) ofColor(Color color) @safe {
            isTestingColor = true;
            targetColor = color;
            return this;
        }

        override string toString() const {
            return toText(
                subject, " should draw an image ",
                isTestingImage ? toText(targetImage)                     : "",
                isTestingArea  ? toText(" rectangle ", targetArea)       : "",
                isTestingColor ? toText(" of color ", targetColor.toHex) : "",
            );
        }

    };

}

/// Assert true if the node draws a child.
/// Params:
///     parent = Parent node, subject of the test.
///     child  = Child to test. Must be drawn directly.
auto drawsChild(Node parent, Node child = null) {

    return new class BlackHole!Assert {

        // 0 outside of parent, 1 inside, 2 in child, 3 in grandchild, etc.
        int parentDepth;

        override bool resume(Node node) {
            if (parent.opEquals(node).assertNotThrown) {
                parentDepth = 1;
            }
            return false;
        }

        override bool beforeDraw(Node node, Rectangle, Rectangle, Rectangle) {

            // Found the parent
            if (parent.opEquals(node).assertNotThrown) {
                parentDepth = 1;
            }

            // Parent drew a child, great! End the test if the child meets expectations.
            else if (parentDepth) {
                if (parentDepth++ == 1) {
                    return child is null || node.opEquals(child).assertNotThrown;
                }
            }

            return false;

        }

        override bool afterDraw(Node node, Rectangle, Rectangle, Rectangle) {

            if (parentDepth) {
                parentDepth--;
            }

            return false;

        }

        override string toString() const {
            if (child)
                return format!"%s must draw %s"(parent, child);
            else
                return format!"%s must draw a child"(parent);
        }

    };

}

///
@("drawsChild assert works as expected")
unittest {

    import fluid.structs;

    Space child, grandchild;

    auto root = testSpace(
        layout!1,
        child = vspace(
            layout!2,
            grandchild = vspace(
                layout!3
            ),
        ),
    );

    root.drawAndAssert(
        root.drawsChild(),
        child.drawsChild(),
    );

    root.drawAndAssert(
        root.drawsChild(child),
        child.drawsChild(grandchild),
    );

    root.drawAndAssert(
        root.drawsChild(child),
        child.drawsChild(grandchild),
        grandchild.doesNotDrawChildren(),
        root.doesNotDrawChildren(),
    );

    root.drawAndAssertFailure(
        root.doesNotDrawChildren(),
    );

    root.drawAndAssertFailure(
        child.doesNotDrawChildren(),
    );

    root.drawAndAssert(
        grandchild.doesNotDrawChildren(),
    );

    root.drawAndAssertFailure(
        grandchild.drawsChild(),
    );

    root.drawAndAssertFailure(
        root.drawsChild(grandchild),
    );

}

/// Make sure the parent does not draw any children.
auto doesNotDrawChildren(Node parent) {

    return new class BlackHole!Assert {

        bool inParent;

        override bool resume(Node node) {
            if (parent.opEquals(node).assertNotThrown) {
                inParent =  true;
            }
            return false;
        }

        override bool beforeDraw(Node node, Rectangle, Rectangle, Rectangle) {

            // Found the parent
            if (parent.opEquals(node).assertNotThrown) {
                inParent = true;
            }

            // Parent drew a child
            else if (inParent) {
                assert(false, format!"%s must not draw children"(parent).assertNotThrown);
            }

            return false;

        }

        override bool afterDraw(Node node, Rectangle, Rectangle, Rectangle) {
            return parent.opEquals(node).assertNotThrown;
        }

        override string toString() const {
            return format!"%s must not draw children"(parent).assertNotThrown;
        }

    };

}

/// Assert true if the parent requests drawing the node,
/// but the node does not need to draw anything for the assert to succeed.
auto isDrawn(Node subject) {

    return new class BlackHole!Assert {

        override bool resume(Node node) {
            return node.opEquals(subject).assertNotThrown;
        }

        override bool beforeDraw(Node node, Rectangle, Rectangle, Rectangle) {
            return node.opEquals(subject).assertNotThrown;
        }

        override string toString() const {
            return format!"%s must be reached"(subject);
        }

    };


}

/// Make sure the selected node draws, but doesn't matter what.
auto draws(Node subject) {

    return drawsWildcard!((node, methodName) {

        return node.opEquals(subject).assertNotThrown
            && methodName.startsWith("draw");

    })(format!"%s should draw"(subject));

}

/// Make sure the selected node doesn't draw anything until another node does.
auto doesNotDraw(Node subject) {

    bool matched;
    string failedName;

    return drawsWildcard!((node, methodName) {

        // Test failed, skip checks
        if (failedName) return false;

        const isSubject = node.opEquals(subject).assertNotThrown;

        // Make sure the node is reached
        if (!matched) {
            if (!isSubject) {
                return false;
            }
            matched = true;
        }

        // Switching to another node
        if (methodName == "beforeDraw" && !isSubject) {
            return true;
        }

        // Ending this node
        if (methodName == "afterDraw" && isSubject) {
            return true;
        }

        if (isSubject && methodName.startsWith("draw")) {
            failedName = methodName;
            return false;
        }

        return false;

    })(matched ? format!"%s shouldn't draw, but calls %s"(subject, failedName)
               : format!"%s should be reached"(subject));

}

/// Ensure the node emits a debug signal.
auto emits(Node subject, string name) {

    return new class BlackHole!Assert {

        override bool emitSignal(Node node, string emittedName) {

            return subject.opEquals(node).assertNotThrown
                && name == emittedName;

        }

        override string toString() const {
            return format!"%s should emit %s"(subject, name);
        }

    };

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

        override bool emitSignal(Node node, string) nothrow {
            return dg(node, "emitSignal");
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

        override bool drawLine(Node node, Vector2, Vector2, float, Color) nothrow {
            return dg(node, "drawLine");
        }

        override bool drawImage(Node node, DrawableImage, Rectangle, Color) nothrow {
            return dg(node, "drawImage");
        }

        override bool drawHintedImage(Node node, DrawableImage, Rectangle, Color) nothrow {
            return dg(node, "drawHintedImage");
        }

        override string toString() const {
            return message;
        }

    };

}

private bool equal(float a, float b) nothrow {

    const diff = a - b;

    return diff >= -0.01
        && diff <= +0.01;

}
