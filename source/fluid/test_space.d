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
import std.algorithm;
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

    // TODO DPI tests

    private {

        struct LoadedImage {
            Image image;
            int lastResize;
        }

        /// Probe the space will use to analyze the tree.
        TestProbe _probe;

        /// Number of calls made to `resize`.
        int _resizeNumber;

        /// All presently loaded images.
        LoadedImage[] _loadedImages;
        int[size_t] _imageIndices;

    }

    this(Node[] nodes...) {

        super(nodes);

        // Create a probe for testing.
        this._probe = new TestProbe();

    }

    /// Returns: True if the given image is loaded.
    bool isImageLoaded(DrawableImage image) nothrow {

        const ptr = cast(size_t) image.data.ptr;

        // Image is registered, OK
        if (auto index = ptr in _imageIndices) {
            assert(*index == image.id, "Image index doesn't match assigned ID.");
            return true;
        }

        // Not loaded
        return false;

    }

    /// Returns: The number of images registered by the test runner.
    int countLoadedImages() nothrow const {

        return cast(int) _loadedImages.length;

    }

    override void resizeImpl(Vector2 space) {

        auto frame = this.implementIO();

        _resizeNumber++;
        super.resizeImpl(space);

        // Garbage-collect images
        foreach_reverse (i, ref image; _loadedImages) {

            // Still valid, continue
            if (image.lastResize >= _resizeNumber) continue;

            // Remove the image
            _loadedImages = _loadedImages.remove(i);
            _imageIndices.remove(cast(size_t) image.image.data.ptr);

        }

    }

    override void cropArea(Rectangle area) nothrow {

        _probe.runAssert(a => a.cropArea(_probe.subject, area));

    }

    override void resetCropArea() nothrow {

        _probe.runAssert(a => a.resetCropArea(_probe.subject));

    }

    override void drawTriangle(Vector2 x, Vector2 y, Vector2 z, Color color) nothrow {

        _probe.runAssert(a => a.drawTriangle(_probe.subject, x, y, z, color));

    }

    override void drawCircle(Vector2 center, float radius, Color color) nothrow {

        _probe.runAssert(a => a.drawCircle(_probe.subject, center, radius, color));

    }

    override void drawRectangle(Rectangle rectangle, Color color) nothrow {

        _probe.runAssert(a => a.drawRectangle(_probe.subject, rectangle, color));

    }

    override void drawImage(DrawableImage image, Rectangle destination, Color tint) nothrow {

        assert(
            isImageLoaded(image), 
            "Trying to draw an image without loading");

        _probe.runAssert(a => a.drawImage(_probe.subject, image, destination, tint));

    }

    override void drawHintedImage(DrawableImage image, Rectangle destination, Color tint) nothrow {

        assert(
            isImageLoaded(image), 
            "Trying to draw an image without loading");

        _probe.runAssert(a => a.drawHintedImage(_probe.subject, image, destination, tint));

    }

    override int load(Image image) nothrow {

        const ptr = cast(size_t) image.data.ptr;

        // If the image is already loaded, mark it as so
        if (auto index = ptr in _imageIndices) {
            _loadedImages[*index].lastResize = _resizeNumber;
            return *index;
        }

        // If not, add it
        else {
            const index = cast(int) _loadedImages.length;

            _loadedImages ~= LoadedImage(image, _resizeNumber);
            _imageIndices[ptr] = index;

            return index;
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

/// Params:
///     subject = Test if this subject draws an image.
/// Returns:
///     An `Assert` that can be passed to `TestSpace.drawAndAssert` to test if a node draws an image.
auto drawsImage(Node subject, Image image) {

    auto test = drawsImage(subject);
    test.isTestingImage = true;
    test.targetImage = image;
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

        override bool drawImage(Node node, DrawableImage image, Rectangle rect, Color color) nothrow {

            if (!node.opEquals(subject).assertNotThrown) return false;

            if (isTestingImage) {
                assert(image.data is image.data);
            }

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

        typeof(this) at(Vector2 position) @safe {
            isTestingArea = true;
            targetArea = Rectangle(position.tupleof, targetImage.size.tupleof);
            // TODO DPI
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
                subject, " should draw an image",
                isTestingImage ? toText(" image ", targetImage)          : "",
                isTestingArea  ? toText(" rectangle ", targetArea)       : "",
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
    bool failed;

    return drawsWildcard!((node, methodName) {

        // Test failed, skip checks
        if (failed) return false;

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

bool equal(float a, float b) nothrow {

    const diff = a - b;

    return diff >= -0.01
        && diff <= +0.01;

}

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
    space.drawAndAssertFailure(
        space.draws(),
    );
    space.drawAndAssertFailure(
        myNode.doesNotDraw()
    );
    space.drawAndAssert(
        myNode.drawsRectangle(),
    );
    space.drawAndAssert(
        myNode.drawsRectangle().ofColor("#f00"),
    );
    space.drawAndAssertFailure(
        myNode.drawsRectangle().ofColor("#500"),
    );
    space.drawAndAssertFailure(
        space.drawsRectangle().ofColor("#500"),
    );

}

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
        test.drawAndAssertFailure(
            root.drawsRectangle(),
            myLabel.isDrawn(),
            root.doesNotDraw(),
        );
        test.drawAndAssertFailure(
            root.doesNotDraw(),
            myLabel.isDrawn(),
            root.drawsRectangle(),
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

@("TestSpace can handle images")
unittest {

    static class MyImage : Space {

        CanvasIO canvasIO;
        DrawableImage image;

        override void resizeImpl(Vector2 space) {
            use(canvasIO);
            load(canvasIO, image);
            super.resizeImpl(space);
        }

        override void drawImpl(Rectangle outer, Rectangle inner) {
            image.draw(inner);
        }

    }
    alias myImage = nodeBuilder!MyImage;

    {
        auto root = myImage();
        auto test = testSpace(root);

        // The image will be loaded and drawn
        test.drawAndAssert(
            root.drawsImage(root.image),
        );
        assert(test.countLoadedImages == 1);

        // The image will not be loaded, but it will be kept alive
        test.drawAndAssert(
            root.drawsImage(root.image),
        );
        assert(test.countLoadedImages == 1);

        // Request a resize — same situation
        test.updateSize();
        test.drawAndAssert(
            root.drawsImage(root.image),
        );
        assert(test.countLoadedImages == 1);

        // Hide the node: the node won't resize and the image will be freed
        root.hide();
        test.drawAndAssertFailure(
            root.isDrawn(),
        );
        assert(test.countLoadedImages == 0);

        // Show the node now and try again
        root.show();
        test.drawAndAssert(
            root.drawsImage(root.image),
        );
        assert(test.countLoadedImages == 1);
    }
    {
        auto image1 = myImage();
        auto image2 = myImage();
        auto test = testSpace(image1, image2);

        assert(image1.image == image2.image);

        // Two nodes draw the same image — counts as one
        test.drawAndAssert(
            image1.drawsImage(image1.image),
            image2.drawsImage(image2.image),
        );
        assert(test.countLoadedImages == 1);

        // Hide one image
        image1.hide();
        test.drawAndAssert(
            image2.drawsImage(image2.image),
        );
        test.drawAndAssertFailure(
            image1.drawsImage(image1.image),
        );
        assert(test.countLoadedImages == 1);

        // Hide both — the images should unload
        image2.hide();
        test.drawAndAssertFailure(
            image1.drawsImage(image1.image),
        );
        test.drawAndAssertFailure(
            image2.drawsImage(image2.image),
        );
        assert(test.countLoadedImages == 0);

        // Show one again
        image2.show();
        test.drawAndAssert(
            image2.drawsImage(image2.image),
        );
        test.drawAndAssertFailure(
            image1.drawsImage(image1.image),
        );
        assert(test.countLoadedImages == 1);
    }

}
