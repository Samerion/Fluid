/// This module contains interfaces for drawing geometry on a canvas.
module fluid.io.canvas;

import optional;

import fluid.types;
import fluid.backend;
import fluid.future.context;

@safe:

/// I/O interface for canvas drawing functionality.
///
/// The canvas should use a coordinate system where (0,0) is the top-left corner. Every increment of 1 is equivalent 
/// to the distance of 1/96th of an inch. Consequentially, (96, 96) is 1 inch down and 1 inch right from the top-left
/// corner of the canvas.
///
/// The canvas should allow all inputs and never throw. If there's a defined boundary, the canvas should crop all 
/// geometry to fit.
interface CanvasIO : IO {

    /// Determines the screen's pixel density. A higher value will effectively scale up the interface, but keeping all
    /// detail. The I/O system should trigger a resize when this changes.
    ///
    /// Note that this value refers to pixels in the physical sense, as in the dots on the screen, as opposed to pixels
    /// as a unit. In other places, Fluid uses pixels (or "px") to refer to 1/96th of an inch.
    ///
    /// For primitive systems, a value of `(96, 96)` may be a good guess. If possible, please fetch this value from
    /// the operating system.
    ///
    /// Returns:
    ///     Current [dots-per-inch value](https://en.wikipedia.org/wiki/Dots_per_inch) per axis.
    Vector2 dpi() const nothrow;

    /// Convert pixels to screen-dependent dots.
    ///
    /// In Fluid, pixel is a unit equal to 1/96th of an inch.
    ///
    /// Params:
    ///     pixels = Value in pixels.
    /// Returns:
    ///     Corresponding value in dots.
    final Vector2 toDots(Vector2 pixels) const nothrow {

        const dpi = this.dpi;

        return Vector2(
            pixels.x * dpi.x / 96,
            pixels.y * dpi.y / 96,
        );

    }

    /// Measure distance in pixels taken by a number of dots.
    ///
    /// In Fluid, pixel is a unit equal to 1/96th of an inch.
    ///
    /// Params:
    ///     dots = Value in dots.
    /// Returns:
    ///     Corresponding value in pixels.
    final Vector2 fromDots(Vector2 dots) const nothrow {

        const dpi = this.dpi;

        return Vector2(
            dots.x / dpi.x * 96,
            dots.y / dpi.y * 96,
        );

    }

    @("toDots/fromDots performs correct conversion")
    unittest {

        import std.typecons;

        auto canvasIO = new class BlackHole!CanvasIO {

            override Vector2 dpi() const nothrow {
                return Vector2(96, 120);
            }

        };

        assert(canvasIO.toDots(Vector2(10, 10)) == Vector2(10, 12.5));
        assert(canvasIO.fromDots(Vector2(10, 10)) == Vector2(10, 8));

    }

    /// Getter for the current crop area, if one is set. Any shape drawn is cropped to fit this area on the canvas.
    ///
    /// This may be used by nodes to skip objects that are outside of the area. For this reason, a canvas system may
    /// (and should) provide a value corresponding to the entire canvas, even if no crop area has been explicitly set.
    ///
    /// Returning an empty value may be desirable if the canvas is some form of persistent storage,
    /// like a printable document or vector image, where the entire content may be displayed all at once.
    ///
    /// Returns:
    ///     An area on the canvas that shapes can be drawn in.
    Optional!Rectangle cropArea() const nothrow;

    /// Set an area the shapes can be drawn in. Any shape drawn after this call will be cropped to fit the specified
    /// rectangle on the canvas.
    ///
    /// Calling this again will replace the old area. `resetCropArea` can be called to remove this area.
    ///
    /// Params:
    ///     area = Area on the canvas to restrict all subsequently drawn shapes to.
    ///         If passed an empty `Optional`, calls `resetCropArea`.
    void cropArea(Rectangle area) nothrow;

    /// ditto
    final void cropArea(Optional!Rectangle area) nothrow {

        // Reset the area if passed None()
        if (area.empty) {
            resetCropArea();
        }

        // Crop otherwise
        else {
            cropArea(area.front);
        }

    }

    /// If `cropArea` was called before, this will reset set area, disabling the effect.
    void resetCropArea() nothrow;

    /// Draw a triangle, consisting of 3 vertices with counter-clockwise winding.
    /// Params:
    ///     a = First of the three points to connect.
    ///     b = Second of the three points to connect.
    ///     c = Third of the three points to connect.
    ///     color = Color to fill the triangle with.
    protected void drawTriangleImpl(Vector2 a, Vector2 b, Vector2 c, Color color) nothrow;

    /// ditto
    final void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) nothrow {

        drawTriangleImpl(a, b, c, 
            multiply(treeContext.tint, color));

    }

    /// Draw a circle.
    /// Params:
    ///     center = Position of the circle's center.
    ///     radius = Radius of the circle.
    ///     color  = Color to fill the circle with.
    protected void drawCircleImpl(Vector2 center, float radius, Color color) nothrow;

    final void drawCircle(Vector2 center, float radius, Color color) nothrow {

        drawCircleImpl(center, radius, 
            multiply(treeContext.tint, color));

    }

    /// Draw a rectangle.
    /// Params:
    ///     rectangle = Rectangle to draw.
    ///     color     = Color to fill the rectangle with.
    protected void drawRectangleImpl(Rectangle rectangle, Color color) nothrow;

    final void drawRectangle(Rectangle rectangle, Color color) nothrow {

        drawRectangleImpl(rectangle,
            multiply(treeContext.tint, color));

    }

    /// Prepare an image for drawing. For hardware accelerated backends, this may involve uploading the texture
    /// to the GPU.
    ///
    /// An image may be passed to this function even if it was already loaded. The field `image.data.ptr` can be used
    /// to uniquely identify an image, so the canvas can use it to reuse previously prepared images. Additionally,
    /// the `image.revisionNumber` field will increase if the image was updated, so the change should be reflected
    /// in the canvas.
    ///
    /// There is no corresponding `unload` call. The canvas can instead unload images based on whether they 
    /// were loaded during a resize. This may look similar to this:
    ///
    /// ---
    /// int resizeNumber;
    /// void load(Image image) {
    ///     // ... load the resource ...
    ///     resource.lastResize = resizeNumber;
    /// }
    /// void resizeImpl(Vector2 space) {
    ///     auto frame = this.implementIO();
    ///     resizeNumber++;
    ///     super.resizeImpl();
    ///     foreach_reverse (ref resource; resources) {
    ///         if (resource.lastResize < resizeNumber) {
    ///             unload(resource);
    ///             resource.isInvalid = true;
    ///         }
    ///     }    
    ///     return size;
    /// }
    /// ---
    ///
    /// Important:
    ///     To make [partial resizing](https://git.samerion.com/Samerion/Fluid/issues/118) possible, 
    ///     `load` can also be called outside of `resizeImpl`.
    ///
    ///     Unloading resources may change resource indices, but `load` calls must then set the new indices.
    /// Params:
    ///     image = Image to prepare. 
    ///         The image may be uninitialized, in which case the image should still be valid, but simply empty.
    ///         Attention should be paid to the `revisionNumber` field.
    /// Returns:
    ///     A number to be associated with the image. Interpretation of this number is up to the backend, but usually
    ///     it will be an index in an array, since it is faster to look up than an associative array.
    int load(Image image) nothrow;

    /// Draw an image on the canvas. 
    ///
    /// `drawImage` is the usual method, which enables scaling and filtering, likely making it preferable 
    /// for most images. However, this may harm images that have been generated (like text) or adjusted to display 
    /// on the user's screen (like icons), so `drawHintedImage` may be preferrable. For similar reasons, 
    /// `drawHintedImage` may also be better for pixel art images.
    /// 
    /// While specifics of `drawImage` are left to the implementation, `drawHintedImage` should directly blit 
    /// the image or use nearest-neighbor to scale, if needed. Image boundaries should be adjusted to align exactly
    /// with the screen's pixel grid.
    ///
    /// Params:
    ///     image       = Image to draw. The image must be prepared with `Node.load` before.
    ///     destination = Position to place the image's top-left corner at or rectangle to fit the image in. 
    ///         The image should be stretched to fit this box.
    ///     tint        = Color to modulate the image against. Every pixel in the image should be multiplied 
    ///         channel-wise by this color; values `0...255` should be mapped to `0...1`.
    protected void drawImageImpl(DrawableImage image, Rectangle destination, Color tint) nothrow;

    /// ditto
    final void drawImage(DrawableImage image, Rectangle destination, Color tint) nothrow {

        drawImageImpl(image, destination, 
            multiply(treeContext.tint, tint));

    }

    /// ditto
    final void drawImage(DrawableImage image, Vector2 destination, Color tint) nothrow {

        const rect = Rectangle(destination.tupleof, image.width, image.height);
        drawImageImpl(image, rect, 
            multiply(treeContext.tint, tint));

    }

    /// ditto
    protected void drawHintedImageImpl(DrawableImage image, Rectangle destination, Color tint) nothrow;

    final void drawHintedImage(DrawableImage image, Rectangle destination, Color tint) nothrow {

        drawHintedImageImpl(image, destination, 
            multiply(treeContext.tint, tint));

    }

    /// ditto
    final void drawHintedImage(DrawableImage image, Vector2 destination, Color tint) nothrow {

        const rect = Rectangle(destination.tupleof, image.width, image.height);
        drawHintedImageImpl(image, rect, 
            multiply(treeContext.tint, tint));

    }

}

/// A `DrawableImage` is a variant of `Image` that can be associated with a `CanvasIO` in order to be drawn.
/// 
/// Prepare images for drawing using `load()` in `resizeImpl`:
///
/// ---
/// CanvasIO canvasIO;
/// DrawableImage image;
/// void resizeImpl(Vector2 space) {
///     require(canvasIO);
///     load(canvasIO, image);
/// }
/// ---
///
/// Draw images in `drawImpl`:
///
/// ---
/// void drawImpl(Rectangle outer, Rectangle inner) {
///     image.draw(inner.start);
/// }
/// ---
struct DrawableImage {

    /// Image to be drawn.
    Image image;

    /// Canvas IO responsible for drawing the image.
    private CanvasIO _canvasIO;

    /// ID for the image assigned by the canvas.
    private int _id;

    alias image this;

    /// Compare two images
    bool opEquals(const DrawableImage other) const {

        // Do not compare I/O metadata
        return image == other.image;

    }

    /// Assign an image to draw.
    Image opAssign(Image other) {
        this.image = other;
        this._canvasIO = null;
        this._id = 0;
        return other;
    }

    /// Returns: The ID/index assigned by `CanvasIO` when this image was loaded.
    int id() const nothrow {
        return this._id;
    }

    void load(CanvasIO canvasIO, int id) nothrow {

        this._canvasIO = canvasIO;
        this._id = id;

    }

    /// Draw the image.
    ///
    /// `draw` is the usual method, which enables scaling and filtering, likely making it preferable 
    /// for most images. However, for images that have been generated (like text) or adjusted to display 
    /// on the user's screen (like icons), `drawHinted` may be preferrable. 
    ///
    /// See_Also: 
    ///     `CanvasIO.drawImage`,
    ///     `CanvasIO.drawHintedImage`
    /// Params:
    ///     destination = Place in the canvas to draw the texture to. 
    ///         If a rectangle is given, the image will stretch to fix this box.
    ///     tint        = Color to multiply the image by. Can be used to reduce opacity, darken or change color. 
    ///         Defaults to white (no change).
    void draw(Rectangle destination, Color tint = Color(0xff, 0xff, 0xff, 0xff)) nothrow {
        _canvasIO.drawImage(this, destination, tint);
    }

    /// ditto
    void draw(Vector2 destination, Color tint = Color(0xff, 0xff, 0xff, 0xff)) nothrow {
        _canvasIO.drawImage(this, destination, tint);
    }

    /// ditto
    void drawHinted(Rectangle destination, Color tint = Color(0xff, 0xff, 0xff, 0xff)) nothrow {
        _canvasIO.drawHintedImage(this, destination, tint);
    }

    /// ditto
    void drawHinted(Vector2 destination, Color tint = Color(0xff, 0xff, 0xff, 0xff)) nothrow {
        _canvasIO.drawHintedImage(this, destination, tint);
    }

}
