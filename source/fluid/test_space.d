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

/// Node property for `TestSpace` that enables cropping. This will prevent overflowing content from being drawn.
/// This can be used to test nodes that rely on cropping information, for example to limit drawn content to what
/// is visible on the screen.
///
/// To control size of the viewport, use `fluid.size_lock.SizeLock` and `fluid.size_lock.sizeLimit`.
///
/// Params:
///     enabled = Controls if cropping should be enabled or disabled. Defaults to `true`.
/// See_Also:
///     `CanvasIO.cropArea`
auto cropViewport(bool enabled = true) {

    static struct CropViewport {

        bool enabled;

        void apply(TestSpace node) {
            node.cropViewport = enabled;
        }

    }

    return CropViewport(enabled);

}

/// This node allows automatically testing if other nodes draw their contents as expected.
class TestSpace : Space, CanvasIO, DebugSignalIO {

    // TODO DPI tests

    public {

        /// If true, test space will set the default crop area to its own viewport size.
        /// By default `TestSpace` exposes an infinite crop area, disabling any clipping behavior.
        /// Enabling this again is useful if testing a node's cropping behavior.
        ///
        /// The viewport size is controlled by the node's own size. The canvas available to its children
        /// will be the same size as `TestSpace`'s contents would normally be. `fluid.size_lock.SizeLock` can be used
        /// to set a specific size.
        bool cropViewport;

    }

    private {

        /// Probe the space will use to analyze the tree.
        TestProbe _probe;

        /// Current crop area.
        Optional!Rectangle _cropArea;

        /// Rectangle given to TestSpace when drawing.
        Rectangle _viewport;

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

        _viewport = Rectangle(0, 0, space.tupleof);
        resetCropArea();

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

    override void drawImpl(Rectangle outer, Rectangle inner) {

        _viewport = inner;
        resetCropArea();
        super.drawImpl(outer, inner);

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
        if (cropViewport) {
            _cropArea = _viewport;
        }
        else {
            _cropArea = none;
        }
    }

    override void drawTriangleImpl(Vector2 x, Vector2 y, Vector2 z, Color color) nothrow {
        _probe.runAssert(a => a.drawTriangle(_probe.subject, x, y, z, color));
    }

    override void drawCircleImpl(Vector2 center, float radius, Color color) nothrow {
        _probe.runAssert(a => a.drawCircle(_probe.subject, center, radius, color));
    }

    override void drawCircleOutlineImpl(Vector2 center, float radius, float width, Color color) nothrow {
        _probe.runAssert(a => a.drawCircleOutline(_probe.subject, center, radius, width, color));
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

    /// Draw a single frame and save the output to an SVG file at given location.
    ///
    /// Requires Fluid to be built with SVG support. To do so, set version `Fluid_SVG` and include dependencies
    /// `elemi` and `arsd-official:image_files`.
    version (Fluid_SVG)
    void drawToSVG(string filename) {

        auto generator = dumpDrawsToSVG(null, filename);
        _probe.asserts = [generator];
        queueAction(_probe);
        draw();
        generator.saveSVG();

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
    bool drawCircleOutline(Node node, Vector2 center, float radius, float width, Color color) nothrow;
    bool drawRectangle(Node node, Rectangle rectangle, Color color) nothrow;
    bool drawLine(Node node, Vector2 start, Vector2 end, float width, Color color) nothrow;
    bool drawImage(Node node, DrawableImage image, Rectangle destination, Color tint) nothrow;
    bool drawHintedImage(Node node, DrawableImage image, Rectangle destination, Color tint) nothrow;

    // Meta
    string toString() const;

}

///
auto cropsTo(Node subject, typeof(Rectangle.tupleof) rectangle) {
    return cropsTo(subject, Rectangle(rectangle));
}

/// ditto
auto cropsTo(Node subject, Rectangle rectangle) {
    auto result = crops(subject);
    result.isTestingArea = true;
    result.targetArea = rectangle;
    return result;
}

/// ditto
auto crops(Node subject) {

    return new class BlackHole!Assert {

        bool isTestingArea;
        Rectangle targetArea;

        override bool cropArea(Node node, Rectangle area) nothrow {

            if (isTestingArea) {
                if (!equal(area.x, targetArea.x)
                    || !equal(area.y, targetArea.y)
                    || !equal(area.w, targetArea.w)
                    || !equal(area.h, targetArea.h)) return false;
            }

            return subject.opEquals(node).assumeWontThrow;

        }

        override string toString() const {
            return toText(subject, " should set crop area")
                ~ (isTestingArea ? toText(" to ", targetArea) : "");
        }

    };

}

///
auto resetsCrop(Node subject) {

    return new class BlackHole!Assert {

        override bool resetCropArea(Node node) nothrow {
            return subject.opEquals(node).assumeWontThrow;
        }

        override string toString() const {
            return toText(subject, " should reset crop area");
        }

    };

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

/// Test if the subject draws a circle outline.
auto drawsCircleOutline(Node subject) {
    auto a = drawsCircle(subject);
    a.isOutline = true;
    return a;
}

/// ditto
auto drawsCircleOutline(Node subject, float width) {
    auto a = drawsCircleOutline(subject);
    a.isTestingOutlineWidth = true;
    a.targetOutlineWidth = width;
    return a;
}

/// Test if the subject draws a circle.
auto drawsCircle(Node subject) {

    return new class BlackHole!Assert {

        bool isOutline;
        bool isTestingCenter;
        Vector2 targetCenter;
        bool isTestingRadius;
        float targetRadius;
        bool isTestingColor;
        Color targetColor;
        bool isTestingOutlineWidth;
        float targetOutlineWidth;

        override bool drawCircle(Node node, Vector2 center, float radius, Color color) nothrow {
            if (isOutline) {
                return false;
            }
            else {
                return drawTargetCircle(node, center, radius, color);
            }
        }

        override bool drawCircleOutline(Node node, Vector2 center, float radius, float width, Color color) nothrow {
            if (isOutline) {
                if (isTestingOutlineWidth) {
                    assert(equal(width, targetOutlineWidth),
                        format!"Expected outline width %s, got %s"(targetOutlineWidth, width).assertNotThrown);
                }
                return drawTargetCircle(node, center, radius, color);
            }
            else {
                return false;
            }
        }

        bool drawTargetCircle(Node node, Vector2 center, float radius, Color color) nothrow @safe {

            if (!node.opEquals(subject).assertNotThrown) return false;

            if (isTestingCenter) {
                if (!equal(targetCenter.x, center.x)
                    || !equal(targetCenter.y, center.y)) return false;
            }

            if (isTestingRadius) {
                if (!equal(targetRadius, radius)) return false;
            }

            if (isTestingColor) {
                if (targetColor != color) return false;
            }

            return true;

        }

        typeof(this) at(float x, float y) @safe {
            return at(Vector2(x, y));
        }

        typeof(this) at(Vector2 center) @safe {
            isTestingCenter = true;
            targetCenter = center;
            return this;
        }

        typeof(this) ofRadius(float radius) @safe {
            isTestingRadius = true;
            targetRadius = radius;
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
                subject, " should draw a circle",
                isOutline             ? "outline"                                : "",
                isTestingCenter       ? toText(" at ", targetCenter)             : "",
                isTestingRadius       ? toText(" of radius ", targetRadius)      : "",
                isTestingOutlineWidth ? toText(" of width ", targetOutlineWidth) : "",
                isTestingColor        ? toText(" of color ", targetColor.toHex)  : "",
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
auto drawsHintedImage(Node subject) {
    auto test = drawsImage(subject);
    test.isTestingHint = true;
    test.targetHint = true;
    return test;
}

/// ditto
auto drawsImage(Node subject) {

    return new class BlackHole!Assert {

        bool isTestingImage;
        Image targetImage;
        bool isTestingStart;
        Vector2 targetStart;
        bool isTestingSize;
        Vector2 targetSize;
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

            if (isTestingStart) {
                assert(equal(targetStart.x, rect.x)
                    && equal(targetStart.y, rect.y),
                    format!"%s should draw image at %s, but draws at %s"(node, targetStart, rect.start)
                        .assertNotThrown);
            }

            if (isTestingSize) {
                assert(equal(targetSize.x, rect.w)
                    && equal(targetSize.y, rect.h),
                    format!"%s should draw image of size %s, but draws %s"(node, targetSize, rect.size)
                        .assertNotThrown);
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
            isTestingStart = true;
            targetStart = position;
            // TODO DPI
            return this;

        }

        typeof(this) at(typeof(Vector2.tupleof) position) @safe {
            return at(Vector2(position));
        }

        typeof(this) at(Rectangle area) @safe {
            at(area.start);
            isTestingSize = true;
            targetSize = area.size;
            return this;

        }

        typeof(this) at(typeof(Rectangle.tupleof) area) @safe {
            return at(Rectangle(area));
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
                isTestingStart ? toText(" at ", targetStart)             : "",
                isTestingSize  ? toText(" of size ", targetSize)         : "",
                isTestingColor ? toText(" of color ", targetColor.toHex) : "",
            );
        }

    };

}

/// Assert true if the node draws a child.
/// Bugs:
///     If testing with a specific child, it will not detect the action if resumed inside of a sibling node.
///     In other words, this will fail:
///
///     ---
///     // tree
///     parent = vspace(
///         sibling = label("Sibling"),
///         child = label("Target"),
///     )
///     // test
///     drawAndAssert(
///         sibling.isDrawn,
///         parent.drawsChild(child),
///     ),
///     ---
///
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

/// Assert true if a node is attempted to be drawn,
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
auto doesNotDraw(alias predicate = `a.startsWith("draw")`)(Node subject) {

    import std.functional : unaryFun;

    bool matched;
    string failedName;

    alias fun = unaryFun!predicate;

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

        if (isSubject && fun(methodName)) {
            failedName = methodName;
            return false;
        }

        return false;

    })(matched ? format!"%s shouldn't draw, but calls %s"(subject, failedName)
               : format!"%s should be reached"(subject));

}

alias doesNotDrawImages = doesNotDraw!`a.among("drawImage", "drawHintedImage")`;

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

        override bool drawCircleOutline(Node node, Vector2, float, float, Color) nothrow {
            return dg(node, "drawCircleOutline");
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

/// Output every draw instruction to stdout (`dumpDraws`), and, optionally, to an SVG file (`dumpDrawsToSVG`).
///
/// Note that `dumpDraws` is equivalent to an `isDrawn` assert. It cannot be mixed with any other asserts on the same
/// node.
///
/// SVG support has to be enabled by passing `Fluid_SVG`.
/// It requires extra dependencies: [elemi](https://code.dlang.org/packages/elemi)
/// and [arsd-official:image_files](https://code.dlang.org/packages/arsd-official%3Aimage_files).
/// To create an SVG image, call `dumpDrawsToSVG`.
/// SVG support is currently incomplete and unstable. Changes can be made to this feature without prior announcement.
///
/// Params:
///     subject  = Subject the output of which should be captured.
///     filename = Path to save the SVG output to. Requires version `Fluid_SVG` to be set, ignored otherwise.
/// Returns:
///     An assert object to pass to `TestSpace.drawAndAssert`.
auto dumpDrawsToSVG(Node subject, string filename = null) {
    auto a = dumpDraws(subject);
    a.generateSVG = true;
    a.svgFilename = filename;
    return a;
}

/// ditto
auto dumpDraws(Node subject) {

    import std.stdio;

    return new class BlackHole!Assert {

        bool generateSVG;
        string svgFilename;

        version (Fluid_SVG) {
            import elemi.xml;
            Element svg;
            bool[Color] tints;
        }

        version (Fluid_SVG)
        Element exportSVG() nothrow @safe {

            return assumeWontThrow(
                elems(
                    Element.XMLDeclaration1_0,
                    elem!"svg"(
                        attr("xmlns") = "http://www.w3.org/2000/svg",
                        attr("version") = "1.1",
                        svg,
                    ),
                ),
            );

        }

        void saveSVG() nothrow @safe {

            import std.file : write;

            version (Fluid_SVG) {
                if (generateSVG && svgFilename !is null) {
                    assumeWontThrow(
                        write(svgFilename, exportSVG)
                    );
                }
            }

        }

        bool isSubject(Node node) nothrow @trusted {
            return subject is null || node.opEquals(subject).assertNotThrown;
        }

        void dump(string fmt, Arguments...)(Node node, Arguments arguments) nothrow @trusted {
            if (isSubject(node)) {
                writefln!fmt(arguments).assertNotThrown;
            }
        }

        override bool afterDraw(Node node, Rectangle, Rectangle, Rectangle) nothrow {
            if (isSubject(node)) {
                saveSVG();
                return true;
            }
            return false;
        }

        override bool cropArea(Node node, Rectangle rectangle) nothrow {
            dump!"node.cropsTo(%s, %s, %s, %s),"(node, rectangle.tupleof);
            return false;
        }

        override bool resetCropArea(Node node) nothrow {
            dump!"node.resetsCrop(),"(node);
            return false;
        }

        override bool emitSignal(Node node, string text) nothrow {
            dump!"node.emits(%(%s%)),"(node, text.only);
            return false;
        }

        override bool drawTriangle(Node node, Vector2 a, Vector2 b, Vector2 c, Color color) nothrow {

            if (isSubject(node)) {
                dump!"drawTriangle(%s, %s, %s, %s),"(node, a, b, c, color.toHex.assumeWontThrow);

                version (Fluid_SVG) if (generateSVG) {
                    assumeWontThrow(
                        svg ~=  elem!"polygon"(
                            attr("points") = [
                                toText(a.x, a.y),
                                toText(b.x, b.y),
                                toText(c.x, c.y),
                            ],
                            attr("fill") = color.toHex,
                        ),
                    );
                }
            }

            return false;
        }

        override bool drawCircle(Node node, Vector2 center, float radius, Color color) nothrow {

            if (isSubject(node)) {
                dump!`node.drawsCircle().at(%s, %s).ofRadius(%s).ofColor("%s"),`
                    (node, center.x, center.y, radius, color.toHex.assumeWontThrow);

                version (Fluid_SVG) if (generateSVG) {
                    assumeWontThrow(
                        svg ~= elem!"circle"(
                            attr("cx")   = toText(center.x),
                            attr("cy")   = toText(center.y),
                            attr("r")    = toText(radius),
                            attr("fill") = color.toHex,
                        ),
                    );
                }
            }

            return false;
        }

        override bool drawCircleOutline(Node node, Vector2 center, float radius, float width, Color color) nothrow {

            if (isSubject(node)) {
                dump!`node.drawsCircleOutline().at(%s).ofRadius(%s).ofColor("%s"),`
                    (node, center, radius, color.toHex.assumeWontThrow);

                version (Fluid_SVG) if (generateSVG) {
                    assumeWontThrow(
                        svg ~= elem!"circle"(
                            attr("cx")           = toText(center.x),
                            attr("cy")           = toText(center.y),
                            attr("r")            = toText(radius),
                            attr("fill")         = "none",
                            attr("stroke")       = color.toHex,
                            attr("stroke-width") = toText(width),
                        ),
                    );
                }
            }

            return false;
        }

        override bool drawRectangle(Node node, Rectangle area, Color color) nothrow {

            if (isSubject(node)) {
                dump!`node.drawsRectangle(%s, %s, %s, %s).ofColor("%s"),`
                    (node, area.tupleof, color.toHex.assumeWontThrow);

                version (Fluid_SVG) if (generateSVG) {
                    assumeWontThrow(
                        svg ~= elem!"rect"(
                            attr("x")      = toText(area.x),
                            attr("y")      = toText(area.y),
                            attr("width")  = toText(area.width),
                            attr("height") = toText(area.height),
                            attr("fill")   = color.toHex,
                        ),
                    );
                }
            }

            return false;
        }

        override bool drawLine(Node node, Vector2 start, Vector2 end, float width, Color color) nothrow {

            if (isSubject(node)) {
                dump!`node.drawsLine().from(%s, %s).to(%s, %s).ofWidth(%s).ofColor("%s"),`
                    (node, start.tupleof, end.tupleof, width, color.toHex.assumeWontThrow);

                version (Fluid_SVG) if (generateSVG) {
                    assumeWontThrow(
                        svg ~= elem!"line"(
                            attr("x1") = toText(start.x),
                            attr("y1") = toText(start.y),
                            attr("x2") = toText(end.x),
                            attr("y2") = toText(end.y),
                            attr("stroke") = color.toHex,
                            attr("stroke-width") = toText(width),
                        ),
                    );
                }
            }

            return false;
        }

        override bool drawImage(Node node, DrawableImage image, Rectangle area, Color color) nothrow {

            if (isSubject(node)) {
                dump!`node.drawsImage().at(%s, %s, %s, %s).ofColor("%s"),`
                    (node, area.tupleof, color.toHex.assumeWontThrow);
                svgImage(image, area, color);
            }

            return false;
        }

        override bool drawHintedImage(Node node, DrawableImage image, Rectangle area, Color color) nothrow {
            if (isSubject(node)) {
                dump!`node.drawsHintedImage().at(%s, %s, %s, %s).ofColor("%s"),`
                    (node, area.tupleof, color.toHex.assumeWontThrow);
                svgImage(image, area, color);
            }
            return false;
        }

        private void svgImage(DrawableImage image, Rectangle area, Color tint) nothrow @trusted {

            version (Fluid_SVG) if (generateSVG) {

                import std.base64;
                import arsd.png;
                import arsd.image;

                ubyte[] data = cast(ubyte[]) image.toRGBA.data;

                // Load the image
                auto arsdImage = new TrueColorImage(image.width, image.height, data);

                // Encode as a PNG in a data URL
                const png = arsdImage.writePngToArray().assumeWontThrow;
                const string base64 = Base64.encode(png);
                const url = "data:image/png;base64," ~ base64;

                assumeWontThrow(
                    svg ~= elems(
                        useTint(tint),
                        elem!"image"(
                            attr("x")      = toText(area.x),
                            attr("y")      = toText(area.y),
                            attr("width")  = toText(area.width),
                            attr("height") = toText(area.height),
                            attr("href")   = url,
                            attr("style")  = format!"filter:url(#%s)"(tint.toHex!"t"),
                        ),
                    ),
                );

            }

        }

        /// Generate a tint filter for the given color
        version (Fluid_SVG)
        private Element useTint(Color color) {

            // Ignore if the given filter already exists
            if (color in tints) return elems();

            tints[color] = true;

            // <pain>
            return elem!"filter"(

                // Use the color as the filter ID, prefixed with "t" instead of "#"
                attr("id") = color.toHex!"t",

                // Create a layer full of that color
                elem!"feFlood"(
                    attr("x") = "0",
                    attr("y") = "0",
                    attr("width") = "100%",
                    attr("height") = "100%",
                    attr("flood-color") = color.toHex,
                ),

                // Blend in with the original image
                elem!"feBlend"(
                    attr("in2") = "SourceGraphic",
                    attr("mode") = "multiply",
                ),

                // Use the source image for opacity
                elem!"feComposite"(
                    attr("in2") = "SourceGraphic",
                    attr("operator") = "in",
                ),

            );
            // </pain>

        }

        override string toString() const {
            return format!"%s must be reached"(subject);
        }

    };

}

private bool equal(float a, float b) nothrow {

    const diff = a - b;

    return diff >= -0.01
        && diff <= +0.01;

}
