///
module fluid.image_view;

import fluid.node;
import fluid.utils;
import fluid.style;
import fluid.backend;

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

    public {

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

        Image texture(Image image) @system {

            clear();
            _texture = tree.io.loadTexture(image);
            _isOwner = true;

            return image;
        }

        /// Load the texture from a filename.
        string texture(string filename) @trusted {

            import std.string : toStringz;

            _texturePath = filename;

            if (tree) {

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

        // Lazy-load the texture if the backend wasn't present earlier
        if (_texture == _texture.init && _texturePath) {

            _texture = tree.io.loadTexture(_texturePath);
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

    override protected void drawImpl(Rectangle, Rectangle rect) @trusted {

        import std.algorithm : min;

        // Ignore if there is no texture to draw
        if (texture.id <= 0) return;

        const size     = fitInto(texture.viewportSize, rect.size);
        const position = center(rect) - size/2;

        _targetArea = Rectangle(position.tupleof, size.tupleof);
        _texture.draw(_targetArea);

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
