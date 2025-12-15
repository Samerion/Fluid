/// This node displays an image. Accepts either a file path (as a [string]), or an [Image].
///
/// <!-- -->
module fluid.image_view;

@safe:

/// Give [imageView] a string, and it will load the image from a file.
@("ImageView string reference")
unittest {
    run(
        imageView("logo.png"),
    );
}

/// Or, if you have the image loaded in memory, pass it as an [Image]:
@("ImageView Image reference")
unittest {
    run(
        imageView(
            generateColorImage(128, 128, color("#7325dc")),
        ),
    );
}

import fluid.node;
import fluid.utils;
import fluid.style;

import fluid.io.file;
import fluid.io.canvas;
import fluid.io.image_load;

/// A [node builder][nodeBuilder] that creates an [ImageView].
alias imageView = nodeBuilder!ImageView;

/// This node property activates the [ImageView.isAutoExpand] field.
/// Params:
///     value = If true, activates automatic expanding. On, by default.
/// Returns:
///     A node property that can be passed to the [imageView] node builder.
auto autoExpand(bool value = true) {
    static struct AutoExpand {
        bool value;

        void apply(ImageView node) {
            node.isAutoExpand = value;
        }
    }
    return AutoExpand(value);
}

/// A node specifically to display images.
///
/// The image will scale to fit the space it is given. It will keep aspect ratio by default and
/// will be displayed in the middle of the available box.
///
/// Note:
///     `ImageView` is heavily affected by recent changes to how Fluid handles I/O.
///
///     * If you only display images from a file, and don't inspect them from code, you will <!--
///       --> *not* be impacted.
///     * The new I/O system *always* uses [Image]. Inspect or change the image using the <!--
///       --> [image][ImageView.image] field.
///     * If using the old backend, you will need to use [Texture]. You will need to manually <!--
///       --> manage its lifetime. Migrating to the new I/O system is highly recommended.
class ImageView : Node {

    CanvasIO canvasIO;
    FileIO fileIO;
    ImageLoadIO imageLoadIO;

    public {

        /// [Image] this node should display, if any. This field only works with the new I/O
        /// system, and requires [CanvasIO] to work.
        ///
        /// See [DrawableImage] for details on how `CanvasIO` handles image drawing.
        DrawableImage image;

        /// If true, size of this imageView is adjusted automatically. Changes made to `minSize`
        /// will be reversed on size update.
        bool isSizeAutomatic;

        /// Experimental. Acquire space from the parent to display the largest image while
        /// preserving aspect ratio. May not work if there's multiple similarly sized nodes in the
        /// same container.
        bool isAutoExpand;

    }

    protected {

        /// If set, path in the filesystem the texture is to be loaded from.
        string _texturePath;

        /// Rectangle occupied by this node after all calculations.
        Rectangle _targetArea;

    }

    /// Create an image node from given image or filename.
    ///
    /// Note:
    ///     If a filename is given, the image will be loaded on the first resize.
    ///     This is done to make sure a backend is available to load the image.
    ///
    /// Params:
    ///     source  = `Texture` struct to use, or a filename to load from.
    ///     minSize = Minimum size of the node. Defaults to image size.
    this(T)(T source, Vector2 minSize) {
        super.minSize = minSize;
        this.texture = source;
    }

    /// ditto
    this(T)(T source) {
        this.texture = source;
        this.isSizeAutomatic = true;
    }

    /// Create an image node using given image.
    /// Params:
    ///     image   = Image to load.
    ///     minSize = Minimum size of the node. Defaults to image size.
    this(Image image, Vector2 minSize) {
        super.minSize = minSize;
        this.image = DrawableImage(image);
    }

    /// ditto
    this(Image image) {
        this.image = DrawableImage(image);
        this.isSizeAutomatic = true;
    }

    ~this() {
        clear();
    }

    /// Change the image displayed by the `ImageView`.
    Image texture(Image image) {
        clear();
        updateSize();
        this.image = image;

        return image;
    }

    /// Load the texture from a filename.
    string texture(string filename) @trusted {
        import std.string : toStringz;

        _texturePath = filename;
        updateSize();

        return filename;
    }

    /// Remove any texture if attached.
    void clear() scope {
        _texturePath = null;
        image = Image.init;
    }

    /// Returns:
    ///     The minimum size for this node.
    ref inout(Vector2) minSize() inout {
        return super.minSize;
    }

    /// Returns:
    ///     Area on the screen the image was last drawn to.
    ///     Updated only when the node is drawn.
    Rectangle targetArea() const {
        return _targetArea;
    }

    override protected void resizeImpl(Vector2 space) @trusted {
        import std.algorithm : min;

        require(canvasIO);
        use(fileIO);
        use(imageLoadIO);

        // Load an image from the filesystem if no image is already loaded
        if (image == Image.init && _texturePath != "" && fileIO && imageLoadIO) {

            auto file = fileIO.loadFile(_texturePath);
            image = imageLoadIO.loadImage(file);

        }

        // Load the image
        load(canvasIO, image);

        // Adjust size
        if (isSizeAutomatic) {
            const viewportSize = image.viewportSize(canvasIO.dpi);

            // No image loaded, shrink to nothingness
            if (image == Image.init) {
                minSize = Vector2(0, 0);
            }
            else if (isAutoExpand) {
                minSize = fitInto(viewportSize, space);
            }
            else {
                minSize = viewportSize;
            }
        }
    }

    override protected void drawImpl(Rectangle, Rectangle inner) @trusted {
        import std.algorithm : min;

        // Ignore if there is no texture to draw
        if (image == Image.init) return;

        const size = image.viewportSize(canvasIO.dpi)
            .fitInto(inner.size);
        const position = center(inner) - size/2;

        _targetArea = Rectangle(position.tupleof, size.tupleof);
        image.draw(_targetArea);
    }

    override protected bool hoveredImpl(Rectangle, Vector2 mouse) const {

        return _targetArea.contains(mouse);

    }

}

/// Returns: A vector smaller than `space` using the same aspect ratio as `reference`.
/// Params:
///     reference = Vector to use the aspect ratio of.
///     space     = Available space; maximum size on each axis for the result vector.
Vector2 fitInto(Vector2 reference, Vector2 space) {

    import std.algorithm : min;

    const scale = min(
        space.x / reference.x,
        space.y / reference.y,
    );

    return reference * scale;

}
