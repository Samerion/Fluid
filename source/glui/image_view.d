///
module glui.image_view;

import raylib;

import glui.node;
import glui.utils;
import glui.style;

alias imageView = simpleConstructor!GluiImageView;

/// A node specifically to display images.
///
/// The image will automatically scale to fit available space. It will keep aspect ratio by default and will be
/// displayed in the middle of the available box.
class GluiImageView : GluiNode {

    mixin DefineStyles!();

    /// Texture for this node.
    private Texture _texture;

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

    /// Set the texture.
    void texture(Texture texture) {

        this._texture = texture;

    }

    /// Load the texture from a filename.
    void texture(string filename) {

        import std.string : toStringz;

        texture = LoadTexture(filename.toStringz);
        updateSize();

    }

    /// Get the current texture.
    const(Texture) texture() const {

        return _texture;

    }

    /// Minimum size of the image.
    ref inout(Vector2) minSize() inout {

        return super.minSize;

    }

    override protected void resizeImpl(Vector2 space) {

    }

    override protected void drawImpl(Rectangle rect) {

        import std.algorithm : min;

        // Get the scale
        const scale = min(
            rect.width / texture.width,
            rect.height / texture.height
        );

        const source = Rectangle(0, 0, texture.width, texture.height);
        const size   = Vector2(texture.width * scale, texture.height * scale);
        const target = Rectangle(
            rect.x + rect.w/2 - size.x/2, rect.y + rect.h/2 - size.y/2,
            size.x, size.y
        );

        DrawTexturePro(texture, source, target, Vector2(0, 0), 0, Colors.WHITE);

    }

    override const(Style) pickStyle() const {

        return null;

    }

}
