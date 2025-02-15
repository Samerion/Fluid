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
/// Works only with the new I/O system introduced in Fluid 0.7.2.
class ResolutionOverride(T : Node) : T {

    CanvasIO canvasIO;

    public {

        /// Desired resolution for the lock. Specified in dots, rather than Fluid's
        /// DPI-independent pixels, so it will not be affected by the scaling setting
        /// of the desktop environment.
        Vector2 resolution;

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

        const size = canvasIO.fromDots(resolution);
        super.resizeImpl(size);
        minSize = size;
    }

    override Rectangle marginBoxForSpace(Rectangle space) const {
        const size = canvasIO.fromDots(resolution);
        const position = layout.nodeAlign.alignRectangle(space, size);
        return Rectangle(position.tupleof, size.tupleof);
    }

}
