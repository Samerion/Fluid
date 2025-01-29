///
module fluid.image_view;

import fluid.node;
import fluid.utils;
import fluid.style;
import fluid.backend;

import fluid.io.file;
import fluid.io.canvas;
import fluid.io.image_load;

@safe:

alias imageView = simpleConstructor!ImageView;

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
/// The image will automatically scale to fit available space. It will keep aspect ratio by default and will be
/// displayed in the middle of the available box.
class ImageView : Node {

    CanvasIO canvasIO;
    FileIO fileIO;
    ImageLoadIO imageLoadIO;

    public {

        /// Image this node should display, if any. Requires an active `CanvasIO` to display.
        DrawableImage image;

        /// If true, size of this imageView is adjusted automatically. Changes made to `minSize` will be reversed on
        /// size update.
        bool isSizeAutomatic;

        /// Experimental. Acquire space from the parent to display the largest image while preserving aspect ratio.
        /// May not work if there's multiple similarly sized nodes in the same container.
        bool isAutoExpand;

    }

    protected {

        /// Texture for this node.
        Texture _texture;

        /// If set, path in the filesystem the texture is to be loaded from.
        string _texturePath;

        /// Rectangle occupied by this node after all calculations.
        Rectangle _targetArea;

    }

    /// Set to true if the image view owns the texture and manages its ownership.
    private bool _isOwner;

    /// Create an image node from given texture or filename.
    ///
    /// Note, if a string is given, the texture will be loaded when resizing. This ensures a Fluid backend is available
    /// to load the texture.
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

    @property {

        /// Set the texture.
        Texture texture(Texture texture) {

            clear();
            _isOwner = false;
            _texturePath = null;

            return this._texture = texture;

        }

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

            if (tree && !canvasIO) {

                clear();
                _texture = tree.io.loadTexture(filename);
                _isOwner = true;

            }

            updateSize();

            return filename;

        }

        /// Get the current texture.
        const(Texture) texture() const {

            return _texture;

        }

    }

    /// Release ownership over the displayed texture.
    ///
    /// Keep the texture alive as long as it's used by this `imageView`, free it manually using the `destroy()` method.
    Texture release() {

        _isOwner = false;
        return _texture;

    }

    /// Remove any texture if attached.
    void clear() @trusted scope {

        // Free the texture
        if (_isOwner) {

            _texture.destroy();

        }

        // Remove the texture
        _texture = texture.init;
        _texturePath = null;

        // Remove the image
        image = Image.init;

    }

    /// Minimum size of the image.
    @property
    ref inout(Vector2) minSize() inout {

        return super.minSize;

    }

    /// Area on the screen the image was last drawn to.
    @property
    Rectangle targetArea() const {

        return _targetArea;

    }

    override protected void resizeImpl(Vector2 space) @trusted {

        import std.algorithm : min;

        use(canvasIO);
        use(fileIO);
        use(imageLoadIO);

        // New I/O system
        if (canvasIO) {

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

        // Old backend
        else {

            // Lazy-load the texture if the backend wasn't present earlier
            if (_texture == _texture.init && _texturePath) {
                _texture = tree.io.loadTexture(_texturePath);
                _isOwner = true;
            }
            else if (_texture == texture.init && image != Image.init) {
                _texture = tree.io.loadTexture(image);
                _isOwner = true;
            }

            // Adjust size
            if (isSizeAutomatic) {

                // No texture loaded, shrink to nothingness
                if (_texture is _texture.init) {
                    minSize = Vector2(0, 0);
                }

                else if (isAutoExpand) {
                    minSize = fitInto(texture.viewportSize, space);
                }

                else {
                    minSize = texture.viewportSize;
                }

            }

        }

    }

    override protected void drawImpl(Rectangle, Rectangle inner) @trusted {

        import std.algorithm : min;

        if (canvasIO) {

            // Ignore if there is no texture to draw
            if (image == Image.init) return;

            const size = image.viewportSize(canvasIO.dpi)
                .fitInto(inner.size);
            const position = center(inner) - size/2;

            _targetArea = Rectangle(position.tupleof, size.tupleof);
            image.draw(_targetArea);

        }

        else {

            // Ignore if there is no texture to draw
            if (texture.id <= 0) return;

            const size     = fitInto(texture.viewportSize, inner.size);
            const position = center(inner) - size/2;

            _targetArea = Rectangle(position.tupleof, size.tupleof);
            _texture.draw(_targetArea);

        }

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
