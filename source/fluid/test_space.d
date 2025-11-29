/// Module for testing Fluid nodes using the new I/O system.
module fluid.test_space;

version (Fluid_TestSpace):

debug (Fluid_BuildMessages) {
    pragma(msg, "Fluid: Including TestSpace");

    version (Fluid_SVG) {
        pragma(msg, "Fluid: Including SVG support in TestSpace");
    }
}

import core.exception;

import optional;

import std.conv : toText = text;
import std.range;
import std.string;
import std.typecons;
import std.algorithm;
import std.exception;
import std.digest.sha;

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

    void setScale(float value) {
        dpi = Vector2(96, 96) * value;
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
        _probe.allowFailure = true;
        scope (exit) _probe.allowFailure = false;
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

    import std.array;
    import std.concurrency;
    import fluid.size_lock;

    public {

        /// Subject that is currently tested.
        Node subject;

        /// Asserts that need to pass before the end of iteration. Asserts that pass are popped off this array.
        Assert[] asserts;

        /// Number of asserts that passed since start of iteration.
        int assertsPassed;

        /// Disables throwing an error if the probe exited with incomplete asserts.
        ///
        /// Every assert needs to finish for a successful test run. `TestProbe` will throw an `AssertError` if it
        /// finishes a run without completing all of the assigned assertions, but this behavior can be disabled
        /// by setting this option to `true`.
        bool allowFailure;

    }

    private {

        /// Node draw stack
        Appender!(Node[]) _stack;

    }

    /// Check an assertion in the `asserts` queue.
    /// Params:
    ///     dg      = Function to run the assert. Returns true if the assert succeeds.
    protected void runAssert(bool delegate(Assert a) @safe dg) nothrow {

        // No tests remain
        if (asserts.empty) return;

        // Test passed, continue to the next one
        if (dg(asserts.front).assumeWontThrow) {
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
        while (!asserts.empty && asserts.front.resume(subject).assumeWontThrow);

    }

    override void started() {

        // Reset pass count
        assertsPassed = 0;

    }

    override void beforeResize(Node node, Vector2) {
        _stack ~= node;
        this.subject = node;
    }

    override void afterResize(Node node, Vector2) {

        // Pop last node
        _stack.shrinkTo(_stack[].length - 1);

        // Restore previous subject from the stack
        if (!_stack[].empty) {
            this.subject = _stack[][$-1];
        }
        else {
            this.subject = null;
        }
    }

    override void beforeDraw(Node node, Rectangle space, Rectangle outer, Rectangle inner) {
        _stack ~= node;
        this.subject = node;
        runAssert(a => a.beforeDraw(node, space, outer, inner));
    }

    override void afterDraw(Node node, Rectangle space, Rectangle outer, Rectangle inner) {

        _stack.shrinkTo(_stack[].length - 1);
        runAssert(a => a.afterDraw(node, space, outer, inner));

        // Restore previous subject from the stack
        if (!_stack[].empty) {
            this.subject = _stack[][$-1];
        }
        else {
            this.subject = null;
        }

    }

    override void stopped() {

        if (allowFailure) return;

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
    bool resume(Node node);

    // Tree
    bool beforeDraw(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox);
    bool afterDraw(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox);

    // DebugSignalIO
    bool emitSignal(Node node, string name);

    // CanvasIO
    bool cropArea(Node node, Rectangle area);
    bool resetCropArea(Node node);
    bool drawTriangle(Node node, Vector2 a, Vector2 b, Vector2 c, Color color);
    bool drawCircle(Node node, Vector2 center, float radius, Color color);
    bool drawCircleOutline(Node node, Vector2 center, float radius, float width, Color color);
    bool drawRectangle(Node node, Rectangle rectangle, Color color);
    bool drawLine(Node node, Vector2 start, Vector2 end, float width, Color color);
    bool drawImage(Node node, DrawableImage image, Rectangle destination, Color tint);
    bool drawHintedImage(Node node, DrawableImage image, Rectangle destination, Color tint);

    // Meta
    string toString() const;

}

abstract class AbstractAssert : BlackHole!Assert {

    Node subject;

    this(Node subject) {
        this.subject = subject;
    }

}

/// Returns:
///     Assert to pass to [TestSpace.drawAndAssert] which runs all given asserts inside `subject`.
///
///     All the asserts must pass sequentially. The first test is started whenever `subject`
///     starts being drawn (on `beforeDraw`), and all tests must pass before `subject` drawing
///     stops (on `afterDraw`).
/// Params:
///     subject = Node to run the tests in.
///     asserts = Asserts to run. All of them must pass for this assert to pass.
ContainsAssert contains(Node subject, Assert[] asserts...) {
    return new ContainsAssert(subject, asserts.dup);
}

///
@("ContainsAssert works as expected")
unittest {
    import fluid.label;

    Space groupOrange;
    Space groupBrown;
    Label sentinelRust;
    Label sentinelWood;
    auto root = testSpace(
        groupOrange = vspace(
            sentinelRust = label("Rust is orange"),
            groupBrown = vspace(
                sentinelWood = label("Wood is brown, and brown is orange"),
            ),
        ),
    );

    // Contain tests can be nested
    root.drawAndAssert(
        groupOrange.contains(
            sentinelRust.isDrawn(),
            groupBrown.contains(
                sentinelWood.isDrawn(),
            ),
        ),
    );

    // Contain tests don't have to be direct
    root.drawAndAssert(
        groupOrange.contains(
            sentinelRust.isDrawn(),
            sentinelWood.isDrawn(),
        ),
    );

    // Brown doesn't contain rust
    root.drawAndAssertFailure(
        groupBrown.contains(
            sentinelRust.isDrawn(),
        ),
    );
    // Rust doesn't contain brown
    root.drawAndAssertFailure(
        sentinelRust.contains(
            groupBrown.isDrawn(),
        ),
    );
    // Brown doesn't contain orange
    root.drawAndAssertFailure(
        groupBrown.contains(
            groupOrange.isDrawn(),
        ),
    );
}

class ContainsAssert : AbstractAssert {

    bool inBranch;
    size_t testsPassed;
    Assert[] asserts;

    this(Node subject, Assert[] asserts) {
        super(subject);
        this.asserts = asserts;
    }

    private bool runAssert(alias method, Ts...)(Ts args) {
        if (!inBranch) return false;
        if (testsPassed < asserts.length) {
            auto test = asserts[testsPassed];
            const passed = __traits(child, test, method)(args);
            if (passed) {
                testsPassed++;
            }
        }
        return testsPassed >= asserts.length;
    }

    override {

        // Switch to the node
        bool resume(Node node) {
            inBranch = node is subject;
            return false;
        }
        bool beforeDraw(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) {
            if (node is subject) {
                inBranch = true;
            }
            return runAssert!(Assert.beforeDraw)(node, space, paddingBox, contentBox);
        }
        bool afterDraw(Node node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) {
            runAssert!(Assert.afterDraw)(node, space, paddingBox, contentBox);
            if (node is subject) {
                inBranch = false;
            }
            return testsPassed >= asserts.length;
        }

        // DebugSignalIO
        bool emitSignal(Node node, string name) {
            return runAssert!(Assert.emitSignal)(node, name);
        }

        // CanvasIO
        bool cropArea(Node node, Rectangle area) {
            return runAssert!(Assert.cropArea)(node, area);
        }

        bool resetCropArea(Node node) {
            return runAssert!(Assert.resetCropArea)(node);
        }

        bool drawTriangle(Node node, Vector2 a, Vector2 b, Vector2 c, Color color) {
            return runAssert!(Assert.drawTriangle)(node, a, b, c, color);
        }

        bool drawCircle(Node node, Vector2 center, float radius, Color color) {
            return runAssert!(Assert.drawCircle)(node, center, radius, color);
        }

        bool drawCircleOutline(Node node, Vector2 center, float radius, float width, Color color) {
            return runAssert!(Assert.drawCircleOutline)(node, center, radius, width, color);
        }

        bool drawRectangle(Node node, Rectangle rectangle, Color color) {
            return runAssert!(Assert.drawRectangle)(node, rectangle, color);
        }

        bool drawLine(Node node, Vector2 start, Vector2 end, float width, Color color) {
            return runAssert!(Assert.drawLine)(node, start, end, width, color);
        }

        bool drawImage(Node node, DrawableImage image, Rectangle destination, Color tint) {
            return runAssert!(Assert.drawImage)(node, image, destination, tint);
        }

        bool drawHintedImage(Node node, DrawableImage image, Rectangle destination, Color tint) {
            return runAssert!(Assert.drawHintedImage)(node, image, destination, tint);
        }

        // Meta
        string toString() const {
            if (testsPassed >= asserts.length) {
                return "All tests passed";
            }
            else {
                return asserts[testsPassed].toString;
            }
        }

    }

}

///
CropAssert cropsTo(Node subject, typeof(Rectangle.tupleof) rectangle) {
    return cropsTo(subject,
        Rectangle(rectangle));
}

/// ditto
CropAssert cropsTo(Node subject, Rectangle rectangle) {
    auto result = crops(subject);
    result.targetArea = rectangle;
    return result;
}

/// ditto
CropAssert crops(Node subject) {
    return new CropAssert(subject);
}

class CropAssert : AbstractAssert {

    Nullable!Rectangle targetArea;

    this(Node subject) {
        super(subject);
    }

    override bool cropArea(Node node, Rectangle area) {
        return equal(subject, node)
            && equal(targetArea, area);
    }

    override string toString() const {
        return toText(
            subject, " should set crop area",
            describe(" to ", targetArea)
        );
    }

}

///
ResetCropAssert resetsCrop(Node subject) {
    return new ResetCropAssert(subject);
}

class ResetCropAssert : AbstractAssert {

    this(Node subject) {
        super(subject);
    }

    override bool resetCropArea(Node node) {
        return equal(subject, node);
    }

    override string toString() const {
        return toText(subject, " should reset crop area");
    }

};

///
DrawsRectangleAssert drawsRectangle(Node subject, typeof(Rectangle.tupleof) rectangle) {
    return drawsRectangle(subject,
        Rectangle(rectangle));
}

/// ditto
auto drawsRectangle(Node subject, Rectangle rectangle) {
    auto result = drawsRectangle(subject);
    result.targetArea = rectangle;
    return result;
}

auto drawsRectangle(Node subject) {
    return new DrawsRectangleAssert(subject);
}

class DrawsRectangleAssert : AbstractAssert {

    Nullable!Rectangle targetArea;
    Nullable!Color targetColor;

    this(Node subject) {
        super(subject);
    }

    override bool drawRectangle(Node node, Rectangle area, Color color) {
        return equal(node, subject)
            && equal(targetArea, area)
            && equal(targetColor, color);
    }

    typeof(this) ofColor(string color) @safe {
        return ofColor(.color(color));
    }

    typeof(this) ofColor(Color color) @safe {
        targetColor = color;
        return this;
    }

    override string toString() const {
        return toText(
            subject, " should draw a rectangle",
            describe(" ", targetArea),
            describe(" of color ", targetColor),
        );
    }

};

/// Test if the subject draws a line.
DrawsLineAssert drawsLine(Node subject) {
    return new DrawsLineAssert(subject);

}

class DrawsLineAssert : AbstractAssert {

    Nullable!Vector2 targetStart;
    Nullable!Vector2 targetEnd;
    Nullable!float targetWidth;
    Nullable!Color targetColor;

    this(Node subject) {
        super(subject);
    }

    override bool drawLine(Node node, Vector2 start, Vector2 end, float width, Color color) {
        return equal(subject, node)
            && equal(targetStart, start)
            && equal(targetEnd, end)
            && equal(targetWidth, width)
            && equal(targetColor, color);
    }

    typeof(this) from(float x, float y) @safe {
        return from(Vector2(x, y));
    }

    typeof(this) from(Vector2 start) @safe {
        targetStart = start;
        return this;
    }

    typeof(this) to(float x, float y) @safe {
        return to(Vector2(x, y));
    }

    typeof(this) to(Vector2 end) @safe {
        targetEnd = end;
        return this;
    }

    typeof(this) ofWidth(float width) @safe {
        targetWidth = width;
        return this;
    }

    typeof(this) ofColor(string color) @safe {
        return ofColor(.color(color));
    }

    typeof(this) ofColor(Color color) @safe {
        targetColor = color;
        return this;
    }

    override string toString() const {
        return toText(
            subject, " should draw a line",
            describe(" from ", targetStart),
            describe(" to ", targetEnd),
            describe(" of width ", targetWidth),
            describe(" of color ", targetColor),
        );
    }

};

/// Test if the subject draws a circle outline.
auto drawsCircleOutline(Node subject) {
    auto a = drawsCircle(subject);
    a.isOutline = true;
    return a;
}

/// ditto
auto drawsCircleOutline(Node subject, float width) {
    auto a = drawsCircleOutline(subject);
    a.targetOutlineWidth = width;
    return a;
}

/// Test if the subject draws a circle.
auto drawsCircle(Node subject) {
    return new DrawsCircleAssert(subject);
}

class DrawsCircleAssert : AbstractAssert {

    bool isOutline;
    Nullable!Vector2 targetCenter;
    Nullable!float targetRadius;
    Nullable!Color targetColor;
    Nullable!float targetOutlineWidth;

    this(Node subject) {
        super(subject);
    }

    override bool drawCircle(Node node, Vector2 center, float radius, Color color) {
        return !isOutline
            && equalCircle(node, center, radius, color);
    }

    override bool drawCircleOutline(Node node, Vector2 center, float radius, float width,
        Color color)
    do {
        return isOutline
            && equal(targetOutlineWidth, width)
            && equalCircle(node, center, radius, color);
    }

    bool equalCircle(Node node, Vector2 center, float radius, Color color) {
        return equal(subject, node)
            && equal(targetCenter, center)
            && equal(targetRadius, radius)
            && equal(targetColor, color);
    }

    typeof(this) at(float x, float y) {
        return at(Vector2(x, y));
    }

    typeof(this) at(Vector2 center) {
        targetCenter = center;
        return this;
    }

    typeof(this) ofRadius(float radius) {
        targetRadius = radius;
        return this;
    }

    typeof(this) ofColor(string color) {
        return ofColor(.color(color));
    }

    typeof(this) ofColor(Color color) {
        targetColor = color;
        return this;
    }

    override string toString() const {
        return toText(
            subject, " should draw a circle",
            isOutline ? " outline" : "",
            describe(" at ", targetCenter),
            describe(" of radius ", targetRadius),
            describe(" of width ", targetOutlineWidth),
            describe(" of color ", targetColor),
        );
    }

}

/// Params:
///     subject = Test if this subject draws an image.
/// Returns:
///     An `Assert` that can be passed to `TestSpace.drawAndAssert` to test if a node draws an image.
DrawsImageAssert drawsImage(Node subject, Image image) {
    auto test = drawsImage(subject);
    test.targetImage = image;
    test.targetColor = color("#fff");
    return test;
}

/// ditto
DrawsImageAssert drawsHintedImage(Node subject, Image image) {
    auto test = drawsImage(subject, image);
    test.targetHint = true;
    return test;
}

/// ditto
DrawsImageAssert drawsHintedImage(Node subject) {
    auto test = drawsImage(subject);
    test.targetHint = true;
    return test;
}

/// ditto
DrawsImageAssert drawsImage(Node subject) {
    return new DrawsImageAssert(subject);
}

class DrawsImageAssert : AbstractAssert {

    Nullable!Image targetImage;
    Nullable!(ubyte[]) targetDataHash;
    Nullable!Vector2 targetStart;
    Nullable!Vector2 targetSize;
    Nullable!Color targetColor;
    Nullable!bool targetHint;
    Nullable!(Color[]) targetPalette;

    this(Node subject) {
        super(subject);
    }

    override bool drawImage(Node node, DrawableImage image, Rectangle rect, Color color) {
        return testImage(node, image, rect, color, false);
    }

    override bool drawHintedImage(Node node, DrawableImage image, Rectangle rect, Color color) {
        return testImage(node, image, rect, color, true);
    }

    bool testImage(Node node, DrawableImage image, Rectangle rect, Color color, bool hint) {
        return equal(subject, node)
            && equal(targetImage, image)
            && equal(targetDataHash, sha256Of(image.data)[])
            && equal(targetStart, rect.start)
            && equal(targetSize, rect.size)
            && equal(targetColor, color)
            && equal(targetHint, hint)
            && equal(targetPalette, image.palette);
    }

    /// Test if the image content (using the format it is stored in) matches the hex-encoded
    /// SHA256 hash.
    typeof(this) sha256(string content) @safe {
        import std.conv : to;
        targetDataHash = content
            .chunks(2)
            .map!(a => a.to!ubyte(16))
            .array;
        return this;
    }

    typeof(this) at(Vector2 position) @safe {
        targetStart = position;
        // TODO DPI
        return this;
    }

    typeof(this) at(typeof(Vector2.tupleof) position) @safe {
        return at(Vector2(position));
    }

    typeof(this) at(Rectangle area) @safe {
        at(area.start);
        targetSize = area.size;
        return this;
    }

    typeof(this) at(typeof(Rectangle.tupleof) area) @safe {
        return at(Rectangle(area));
    }

    typeof(this) withPalette(Color[] colors...) @safe {
        targetPalette = colors.dup;
        return this;
    }

    typeof(this) ofColor(string color) @safe {
        return ofColor(.color(color));
    }

    typeof(this) ofColor(Color color) @safe {
        targetColor = color;
        return this;
    }

    override string toString() const {
        return toText(
            subject, " should draw an image",
            describe(" ", targetImage),
            describe(" with SHA256 ", targetDataHash),
            describe(" at ", targetStart),
            describe(" of size ", targetSize),
            describe(" of color ", targetColor),
            describe(" with palette ", targetPalette),
        );
    }

}

/// Assert true if the node draws a child.
///
/// Notes:
///     If testing with a specific child, it will not detect the action if resumed inside of a
///     sibling node. In other words, this will fail:
///
///     ---
///     parent = vspace(
///         sibling = label("Sibling"),
///         child = label("Target"),
///     );
///     drawAndAssert(
///         sibling.isDrawn,
///         parent.drawsChild(child),
///     );
///     ---
///
///     You can instead use [contains]:
///
///     ---
///     drawAndAssert(
///         parent.contains(
///             sibling.isDrawn,
///             child.isDrawn,
///         ),
///     );
///     ---
///
/// Params:
///     parent = Parent node, subject of the test.
///     child  = Child to test.
///         The child must be nested directly in the parent, but this behavior will
///         eventually change, see https://git.samerion.com/Samerion/Fluid/issues/493.
///         If you prefer to stick to current behavior, use [drawsChildDirectly].
DrawsChildAssert drawsChild(Node parent, Node child = null) {
    return new DrawsChildAssert(parent, child);
}

/// At the present moment, this is an alias to [drawsChild]. In a future update, however,
/// the other function will not require direct nesting. See [drawsChild] for details.
alias drawsChildDirectly = drawsChild;

class DrawsChildAssert : AbstractAssert {

    Node child;

    // 0 outside of parent, 1 inside, 2 in child, 3 in grandchild, etc.
    int parentDepth;

    this(Node subject, Node child) {
        super(subject);
        this.child = child;
    }

    override bool resume(Node node) {
        if (equal(subject, node)) {
            parentDepth = 1;
        }
        return false;
    }

    override bool beforeDraw(Node node, Rectangle, Rectangle, Rectangle) {

        // Found the parent
        if (equal(subject, node)) {
            parentDepth = 1;
        }

        // Parent drew a child, great! End the test if the child meets expectations.
        else if (parentDepth) {
            if (parentDepth++ == 1) {
                return child is null || equal(node, child);
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
            return format!"%s must draw %s"(subject, child);
        else
            return format!"%s must draw a child"(subject);
    }

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
///
/// `doesNotDrawChildren` will eventually be replaced by a more appropriate test. See
/// https://git.samerion.com/Samerion/Fluid/issues/347 for details.
auto doesNotDrawChildren(Node parent) {
    return new DoesNotDrawChildrenAssert(parent);

}

class DoesNotDrawChildrenAssert : AbstractAssert {

    bool inParent;

    this(Node subject) {
        super(subject);
    }

    override bool resume(Node node) {
        if (equal(subject, node)) {
            inParent =  true;
        }
        return false;
    }

    override bool beforeDraw(Node node, Rectangle, Rectangle, Rectangle) {

        // Found the parent
        if (equal(subject, node)) {
            inParent = true;
        }

        // Parent drew a child
        else if (inParent) {
            assert(false, format!"%s must not draw children"(subject));
        }

        return false;

    }

    override bool afterDraw(Node node, Rectangle, Rectangle, Rectangle) {
        return equal(subject, node);
    }

    override string toString() const {
        return format!"%s must not draw children"(subject);
    }

}

/// Assert true if a node is attempted to be drawn,
/// but the node does not need to draw anything for the assert to succeed.
IsDrawnAssert isDrawn(Node subject) {
    return new IsDrawnAssert(subject);
}

class IsDrawnAssert : AbstractAssert {

    Nullable!Vector2 targetSpaceStart;
    Nullable!Vector2 targetSpaceSize;

    this(Node node) {
        super(node);
    }

    override bool resume(Node node) {
        return equal(subject, node)
            && targetSpaceStart.isNull
            && targetSpaceSize.isNull;
    }

    override bool beforeDraw(Node node, Rectangle space, Rectangle, Rectangle) {
        return equal(subject, node)
            && equal(targetSpaceStart, space.start)
            && equal(targetSpaceSize, space.size);
    }

    auto at(Rectangle space) @safe {
        targetSpaceStart = space.start;
        targetSpaceSize = space.size;
        return this;
    }

    auto at(float x, float y, float width, float height) @safe {
        return at(Rectangle(x, y, width, height));
    }

    auto at(Vector2 start) @safe {
        targetSpaceStart = start;
        return this;
    }

    auto at(float x, float y) @safe {
        return at(Vector2(x, y));
    }

    override string toString() const {
        return toText(
            subject, " must be drawn",
            describe(" at ", targetSpaceStart),
            describe(" with size ", targetSpaceSize),
        );
    }

}

/// Make sure the selected node draws, but doesn't matter what.
auto draws(Node subject) {
    return drawsWildcard!((node, methodName) {
        return equal(subject, node)
            && methodName.startsWith("draw");

    })(format!"%s should draw"(subject));
}

/// Make sure the selected node doesn't draw anything until another node does.
///
/// `doesNotDraw` will eventually be replaced by a more appropriate test. See
/// https://git.samerion.com/Samerion/Fluid/issues/347 for details.
auto doesNotDraw(alias predicate = `a.startsWith("draw")`)(Node subject) {
    import std.functional : unaryFun;

    bool matched;
    string failedName;

    alias fun = unaryFun!predicate;

    return drawsWildcard!((node, methodName) {

        // Test failed, skip checks
        if (failedName) return false;

        const isSubject = equal(subject, node);

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

// `doesNotDrawImages` will eventually be replaced by a more appropriate test. See
// https://git.samerion.com/Samerion/Fluid/issues/347 for details.
alias doesNotDrawImages = doesNotDraw!`a.among("drawImage", "drawHintedImage")`;

/// Ensure the node emits a debug signal.
EmitsAssert emits(Node subject, string name) {
    return new EmitsAssert(subject, name);
}

class EmitsAssert : AbstractAssert {

    string name;

    this(Node subject, string name) {
        super(subject);
        this.name = name;
    }

    override bool emitSignal(Node node, string emittedName) {
        return equal(subject, node)
            && name == emittedName;

    }

    override string toString() const {
        return toText(subject, " should emit ", name);
    }

}

auto drawsWildcard(alias dg)(string message) {
    return new WildcardAssert!dg(null, message);
}

class WildcardAssert(alias dg) : AbstractAssert {

    string message;

    this(Node subject, string message) {
        super(subject);
        this.message = message;
    }

    override bool resume(Node node) {
        return dg(node, "resume");
    }

    override bool beforeDraw(Node node, Rectangle, Rectangle, Rectangle) {
        return dg(node, "beforeDraw");
    }

    override bool afterDraw(Node node, Rectangle, Rectangle, Rectangle) {
        return dg(node, "afterDraw");
    }

    override bool cropArea(Node node, Rectangle) {
        return dg(node, "cropArea");
    }

    override bool resetCropArea(Node node) {
        return dg(node, "resetCropArea");
    }

    override bool emitSignal(Node node, string) {
        return dg(node, "emitSignal");
    }

    override bool drawTriangle(Node node, Vector2, Vector2, Vector2, Color) {
        return dg(node, "drawTriangle");
    }

    override bool drawCircle(Node node, Vector2, float, Color) {
        return dg(node, "drawCircle");
    }

    override bool drawCircleOutline(Node node, Vector2, float, float, Color) {
        return dg(node, "drawCircleOutline");
    }

    override bool drawRectangle(Node node, Rectangle, Color) {
        return dg(node, "drawRectangle");
    }

    override bool drawLine(Node node, Vector2, Vector2, float, Color) {
        return dg(node, "drawLine");
    }

    override bool drawImage(Node node, DrawableImage, Rectangle, Color) {
        return dg(node, "drawImage");
    }

    override bool drawHintedImage(Node node, DrawableImage, Rectangle, Color) {
        return dg(node, "drawHintedImage");
    }

    override string toString() const {
        return message;
    }

}

/// Output every draw instruction to stdout (`dumpDraws`), and, optionally, to an SVG file
/// (`dumpDrawsToSVG`).
///
/// Note that `dumpDraws` is equivalent to an `isDrawn` assert. It cannot be mixed with any other
/// asserts on the same node.
///
/// SVG support has to be enabled by passing `Fluid_SVG`. It requires
/// extra dependencies: [elemi](https://code.dlang.org/packages/elemi) and
/// [arsd-official:image_files](https://code.dlang.org/packages/arsd-official%3Aimage_files). To
/// create an SVG image, call `dumpDrawsToSVG`. SVG support is currently incomplete and unstable.
/// Changes can be made to this feature without prior announcement.
///
/// Params:
///     subject  = Subject the output of which should be captured.
///     filename = Path to save the SVG output to. Requires version `Fluid_SVG` to be set,
///         ignored otherwise.
/// Returns:
///     An assert object to pass to `TestSpace.drawAndAssert`.
DumpDrawsAssert dumpDrawsToSVG(Node subject, string filename = null) {
    auto a = dumpDraws(subject);
    a.generateSVG = true;
    a.svgFilename = filename;
    return a;
}

/// ditto
DumpDrawsAssert dumpDraws(Node subject) {
    return new DumpDrawsAssert(subject);
}

class DumpDrawsAssert : AbstractAssert {
    import std.stdio;

    bool generateSVG;
    string svgFilename;

    version (Fluid_SVG) {
        import elemi.xml;
        Element svg;
        bool[Color] tints;
    }

    this(Node subject) {
        super(subject);
    }

    version (Fluid_SVG)
    Element exportSVG() @safe {

        return elems(
            Element.XMLDeclaration1_0,
            elem!"svg"(
                attr("xmlns") = "http://www.w3.org/2000/svg",
                attr("version") = "1.1",
                svg,
            ),
        );

    }

    void saveSVG() @safe {

        import std.file : write;

        version (Fluid_SVG) {
            if (generateSVG && svgFilename !is null) {
                write(svgFilename, exportSVG);
            }
        }

    }

    bool isSubject(Node node) @trusted {
        return equal(subject, node);
    }

    void dump(string fmt, Arguments...)(Node node, Arguments arguments) @trusted {
        if (isSubject(node)) {
            writefln!fmt(arguments);
        }
    }

    override bool beforeDraw(Node node, Rectangle space, Rectangle, Rectangle) {
        dump!"node.isDrawn().at(%s, %s, %s, %s),"(node, space.tupleof);
        return false;
    }

    override bool afterDraw(Node node, Rectangle, Rectangle, Rectangle) {
        if (subject && isSubject(node)) {
            saveSVG();
            return true;
        }
        return false;
    }

    override bool cropArea(Node node, Rectangle rectangle) {
        dump!"node.cropsTo(%s, %s, %s, %s),"(node, rectangle.tupleof);
        return false;
    }

    override bool resetCropArea(Node node) {
        dump!"node.resetsCrop(),"(node);
        return false;
    }

    override bool emitSignal(Node node, string text) {
        dump!"node.emits(%(%s%)),"(node, text.only);
        return false;
    }

    override bool drawTriangle(Node node, Vector2 a, Vector2 b, Vector2 c, Color color) {

        if (isSubject(node)) {
            dump!"drawTriangle(%s, %s, %s, %s),"(node, a, b, c, color.toHex);

            version (Fluid_SVG) if (generateSVG) {
                svg ~=  elem!"polygon"(
                    attr("points") = [
                        toText(a.x, a.y),
                        toText(b.x, b.y),
                        toText(c.x, c.y),
                    ],
                    attr("fill") = color.toHex,
                );
            }
        }

        return false;
    }

    override bool drawCircle(Node node, Vector2 center, float radius, Color color) {

        if (isSubject(node)) {
            dump!`node.drawsCircle().at(%s, %s).ofRadius(%s).ofColor("%s"),`
                (node, center.x, center.y, radius, color.toHex);

            version (Fluid_SVG) if (generateSVG) {
                svg ~= elem!"circle"(
                    attr("cx")   = toText(center.x),
                    attr("cy")   = toText(center.y),
                    attr("r")    = toText(radius),
                    attr("fill") = color.toHex,
                );
            }
        }

        return false;
    }

    override bool drawCircleOutline(Node node, Vector2 center, float radius, float width,
        Color color)
    do {

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

    override bool drawRectangle(Node node, Rectangle area, Color color) {

        if (isSubject(node)) {
            dump!`node.drawsRectangle(%s, %s, %s, %s).ofColor("%s"),`
                (node, area.tupleof, color.toHex.assumeWontThrow);

            version (Fluid_SVG) if (generateSVG) {
                svg ~= elem!"rect"(
                    attr("x")      = toText(area.x),
                    attr("y")      = toText(area.y),
                    attr("width")  = toText(area.width),
                    attr("height") = toText(area.height),
                    attr("fill")   = color.toHex,
                );
            }
        }

        return false;
    }

    override bool drawLine(Node node, Vector2 start, Vector2 end, float width, Color color) {

        if (isSubject(node)) {
            dump!`node.drawsLine().from(%s, %s).to(%s, %s).ofWidth(%s).ofColor("%s"),`
                (node, start.tupleof, end.tupleof, width, color.toHex);

            version (Fluid_SVG) if (generateSVG) {
                svg ~= elem!"line"(
                    attr("x1") = toText(start.x),
                    attr("y1") = toText(start.y),
                    attr("x2") = toText(end.x),
                    attr("y2") = toText(end.y),
                    attr("stroke") = color.toHex,
                    attr("stroke-width") = toText(width),
                );
            }
        }

        return false;
    }

    override bool drawImage(Node node, DrawableImage image, Rectangle area, Color color) {
        dumpImage(node, image, area, color, false);
        return false;
    }

    override bool drawHintedImage(Node node, DrawableImage image, Rectangle area, Color color) {
        dumpImage(node, image, area, color, true);
        return false;
    }

    private void dumpImage(Node node, DrawableImage image, Rectangle area, Color tint,
        bool isHinted) @trusted
    do {

        if (!isSubject(node)) return;

        dump!(`node.draws%sImage().at(%s, %s, %s, %s).ofColor("%s")` ~ "\n"
            ~ `    .sha256("%(%02x%)"),`)
            (node, isHinted ? "Hinted" : "", area.tupleof, tint.toHex.assumeWontThrow,
            sha256Of(image.data)[]);

        if (image.area == 0) return;

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
        return toText(subject, " must be reached");
    }

}

private bool equal(float a, float b) nothrow {

    const diff = a - b;

    return diff >= -0.01
        && diff <= +0.01;

}

private bool equal(Node a, Node b) nothrow {

    // Exact same object, or both are nulls
    if (a is b) {
        return true;
    }

    // Either is null (except if both, handled previously)
    if (a is null || b is null) {
        return false;
    }

    // Neither is null, use opEquals
    return a.opEquals(b).assumeWontThrow;

}

/// Returns:
///     True if both floats are the same, or the target is null/unspecified.
private bool equal(Nullable!float target, float subject) {
    if (target.isNull) {
        return true;
    }
    auto targetNN = target.get;
    return equal(targetNN, subject);
}

/// Returns:
///     True if both vectors are the same, or the target is null/unspecified.
private bool equal(Nullable!Vector2 target, Vector2 subject) {
    if (target.isNull) {
        return true;
    }
    auto targetNN = target.get;
    return equal(targetNN.x, subject.x)
        && equal(targetNN.y, subject.y);
}

/// Returns:
///     True if both rectangles are the same, or the target is null/unspecified.
private bool equal(Nullable!Rectangle target, Rectangle subject) {
    if (target.isNull) {
        return true;
    }
    auto targetNN = target.get;
    return equal(targetNN.x, subject.x)
        && equal(targetNN.y, subject.y)
        && equal(targetNN.width, subject.width)
        && equal(targetNN.height, subject.height);
}

private bool equal(Nullable!Image target, Image subject) {
    if (target.isNull) {
        return true;
    }
    auto targetNN = target.get;
    const bothEmpty = targetNN.data.empty
        && subject.data.empty;
    const sameData = bothEmpty
        || targetNN.data is subject.data;
    return targetNN.format == subject.format
        && sameData
        && targetNN.width == subject.width
        && targetNN.height == subject.height;
}

private bool equal(T)(Nullable!(T) target, T subject) {
    if (target.isNull) {
        return true;
    }
    return target.get == subject;
}

private string describe(T : Nullable!E, E)(string prefix, T nullable, string suffix = "") {

    import std.traits : Unqual;

    // Empty strings if this test is disabled
    if (nullable.isNull) {
        return null;
    }

    // Describe colors with hex codes
    else static if (is(const E : Color)) {
        return toText(prefix, nullable.get.toHex, suffix);
    }

    // Hex-encode binary
    else static if (is(const E : const(ubyte)[])) {
        return format!"%s%(%02x%)%s"(prefix, nullable.get, suffix);
    }

    // Remove qualifiers, if allowed: const(Rectangle)(0, 0, 10, 10) -> Rectangle(0, 0, 10, 10)
    else static if (is(const E : Unqual!E)) {
        return toText(prefix, cast() nullable.get, suffix);
    }
    else {
        return toText(prefix, nullable.get, suffix);
    }

}

