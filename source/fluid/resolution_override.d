/// `ResolutionOverride` forcefully changes the resolution a node is drawn in, overriding layout
/// hints. This is useful if Fluid's graphical output is transformed as a post-process step that
/// demands a specific output size. This is commonly the case with Raylib's `RenderTexture`,
/// or Parin's resolution lock.
///
/// Note that scaling Fluid's output as a post-process step will reduce quality, likely making
/// text blurry. It remains useful for pixel art-style applications with bitmap fonts, but for
/// other usecases, check with the `CanvasIO` system provider if it supports scaling. For Raylib,
/// you can use `fluid.raylib.RaylibView.scale`.
module fluid.resolution_override;

import optional;

import fluid.node;
import fluid.utils;
import fluid.types;
import fluid.structs;
import fluid.hover_transform;

import fluid.io.canvas;

/// Node builder for `ResolutionOverride`. It is a template, accepting the base node type
/// (like `resolutionOverride!Frame`) or another node builder (for example
/// `resolutionOverride!hframe`).
alias resolutionOverride(alias base) = nodeBuilder!(ResolutionOverride, base);

/// This node sets a static resolution for its content, ignoring (overriding) whatever layout
/// was assigned by its parent.
///
/// `ResolutionOverride` requires an active instance of `CanvasIO` to work. It will locally
/// override its `dpi` value — with a default of `(96, 96)` —  to make sure the output
/// is consistent. The DPI value can be changed using the `dpi` method.
class ResolutionOverride(T : Node) : T, CanvasIO {

    CanvasIO canvasIO;

    public {

        /// Desired resolution for the lock. Specified in dots, rather than Fluid's
        /// DPI-independent pixels, so it will not be affected by the scaling setting
        /// of the desktop environment.
        Vector2 resolution;

    }

    private {
        auto _dpi = Vector2(96, 96);
    }

    /// Create a node locked to a set resolution.
    /// Params:
    ///     resolution = Resolution to use, in dots.
    ///     args       = Arguments to pass to the base node.
    this(Ts...)(Vector2 resolution, Ts args) @safe {
        super(args);
        this.resolution = resolution;
    }

    override void resizeImpl(Vector2) @safe {
        require(canvasIO);

        auto io = this.implementIO();

        const size = canvasIO.fromDots(resolution);
        super.resizeImpl(size);
        minSize = size;
    }

    override Rectangle marginBoxForSpace(Rectangle space) const {
        const size = canvasIO.fromDots(resolution);
        const position = layout.nodeAlign.alignRectangle(space, size);
        return Rectangle(position.tupleof, size.tupleof);
    }

    override Vector2 dpi() const nothrow {
        return _dpi;
    }

    Vector2 dpi(Vector2 value) nothrow {
        return _dpi = value;
    }

    // CanvasIO overrides

    override Optional!Rectangle cropArea() const nothrow {
        return canvasIO.cropArea();
    }

    override void cropArea(Rectangle area) nothrow {
        canvasIO.cropArea(area);
    }

    override void resetCropArea() nothrow {
        canvasIO.resetCropArea();
    }

    override void drawTriangleImpl(Vector2 a, Vector2 b, Vector2 c, Color color) nothrow {
        canvasIO.drawTriangleImpl(a, b, c, color);
    }

    override void drawCircleImpl(Vector2 center, float radius, Color color) nothrow {
        canvasIO.drawCircleImpl(center, radius, color);
    }

    override void drawCircleOutlineImpl(Vector2 center, float radius, float width, Color color)
    nothrow {
        canvasIO.drawCircleOutlineImpl(center, radius, width, color);
    }

    override void drawRectangleImpl(Rectangle rectangle, Color color) nothrow {
        canvasIO.drawRectangleImpl(rectangle, color);
    }

    override void drawLineImpl(Vector2 start, Vector2 end, float width, Color color) nothrow {
        canvasIO.drawLineImpl(start, end, width, color);
    }

    override int load(Image image) nothrow {
        return canvasIO.load(image);
    }

    override void drawImageImpl(DrawableImage image, Rectangle destination, Color tint) nothrow {
        canvasIO.drawImageImpl(image, destination, tint);
    }

    override void drawHintedImageImpl(DrawableImage image, Rectangle destination, Color tint)
    nothrow {
        canvasIO.drawHintedImageImpl(image, destination, tint);
    }

}
