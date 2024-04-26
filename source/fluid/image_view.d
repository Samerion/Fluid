///
module fluid.image_view;

import fluid.node;
import fluid.utils;
import fluid.style;
import fluid.backend;

alias imageView = simpleConstructor!ImageView;

@safe:

/// A node specifically to display images.
///
/// The image will automatically scale to fit available space. It will keep aspect ratio by default and will be
/// displayed in the middle of the available box.
alias ImageView = SpecialImageView!Texture;

// A node that can display images from any format with a `.draw` function.
class SpecialImageView(ImageType) : Node {

    public {

        /// If true, size of this imageView is adjusted automatically. Changes made to `minSize` will be reversed on
        /// size update.
        bool isSizeAutomatic;

    }

    protected {

        /// Texture for this node.
        ImageType _texture;

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
        ImageType texture(ImageType texture) {

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

        @system unittest {

            // TODO test for keeping aspect ratio
            auto io = new HeadlessBackend(Vector2(1000, 1000));
            auto root = imageView(.nullTheme, "logo.png");

            // The texture will lazy-load
            assert(root.texture == Texture.init);

            root.io = io;
            root.draw();

            // Texture should be loaded by now
            assert(root.texture != Texture.init);

            io.assertTexture(root.texture, Vector2(0, 0), color!"fff");

            version (Have_raylib_d) {
                import std.string: toStringz;
                raylib.Image LoadImage(string path) => raylib.LoadImage(path.toStringz);
                raylib.Texture LoadTexture(string path) => raylib.LoadTexture(path.toStringz);
                void InitWindow() => raylib.InitWindow(80, 80, "");
                void CloseWindow() => raylib.CloseWindow();

                InitWindow;
                raylib.Texture rayTexture = LoadTexture("logo.png");
                fluid.Texture texture = rayTexture.toFluid;

                io.assertTexture(root.texture, Vector2(0, 0), color!"fff");
                CloseWindow;
            }
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

        // Lazy-load the texture if the backend wasn't present earlier
        if (_texture == _texture.init && _texturePath) {

            _texture = tree.io.loadTexture(_texturePath);
            _isOwner = true;

        }

        // Adjust size
        if (isSizeAutomatic) {

            minSize = _texture.viewportSize;

        }

    }

    override protected void drawImpl(Rectangle, Rectangle rect) @trusted {

        import std.algorithm : min;

        // Ignore if there is no texture to draw
        if (texture.id <= 0) return;

        // Get the scale
        const scale = min(
            rect.width / texture.width,
            rect.height / texture.height
        );

        const size     = Vector2(texture.width * scale, texture.height * scale);
        const position = center(rect) - size/2;

        _targetArea = Rectangle(position.tupleof, size.tupleof);
        _texture.draw(_targetArea);

    }

    override protected bool hoveredImpl(Rectangle, Vector2 mouse) const {

        return _targetArea.contains(mouse);

    }

}