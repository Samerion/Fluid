///
module glui.image_view;

import raylib;

import glui.node;
import glui.utils;
import glui.style;

alias imageView = simpleConstructor!GluiImageView;

@safe:

/// A node specifically to display images.
///
/// The image will automatically scale to fit available space. It will keep aspect ratio by default and will be
/// displayed in the middle of the available box.
class GluiImageView : GluiNode {

    mixin DefineStyles;

    /// Texture for this node.
    protected {

        Texture _texture;
        Rectangle _targetArea;  // Rectangle occupied by this node after all calculations

    }

    static foreach (index; 0 .. BasicNodeParamLength) {

        /// Create an image node from given texture or filename.
        /// Params:
        ///     source  = `Texture` raylib struct to use, or a filename to load from.
        ///     minSize = Minimum size of the node
        this(T)(BasicNodeParam!index sup, T source, Vector2 minSize = Vector2(0, 0)) {

            super(sup);
            texture = source;
            super.minSize = minSize;

        }

    }

    @property {

        /// Set the texture.
        Texture texture(Texture texture) {

            return this._texture = texture;

        }

        /// Load the texture from a filename.
        string texture(string filename) @trusted {

            import std.string : toStringz;

            texture = LoadTexture(filename.toStringz);
            updateSize();

            return filename;

        }

        /// Get the current texture.
        const(Texture) texture() const {

            return _texture;

        }

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

    override protected void resizeImpl(Vector2 space) {

    }

    override protected void drawImpl(Rectangle, Rectangle rect) @trusted {

        import std.algorithm : min;

        // Get the scale
        const scale = min(
            rect.width / texture.width,
            rect.height / texture.height
        );

        const source = Rectangle(0, 0, texture.width, texture.height);
        const size   = Vector2(texture.width * scale, texture.height * scale);

        _targetArea = Rectangle(
            rect.x + rect.w/2 - size.x/2, rect.y + rect.h/2 - size.y/2,
            size.x, size.y
        );

        DrawTexturePro(texture, source, _targetArea, Vector2(0, 0), 0, Colors.WHITE);

    }

    override protected bool hoveredImpl(Rectangle, Vector2 mouse) const {

        return _targetArea.contains(mouse);

    }

    override const(Style) pickStyle() const {

        return null;

    }

}
