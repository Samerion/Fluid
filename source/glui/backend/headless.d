module glui.backend.headless;

debug (Glui_BuildMessages) {
    pragma(msg, "Glui: Building with headless backend");
}

import std.math;
import std.array;
import std.range;
import std.string;
import std.sumtype;
import std.algorithm;

import glui.backend;


@safe:


/// Rendering textures in SVG requires arsd.image
version (Have_arsd_official_image_files)
    enum svgTextures = true;
else
    enum svgTextures = false;


class HeadlessBackend : GluiBackend {

    enum State {

        up,
        pressed,
        repeated,
        down,
        released,

    }

    struct DrawnLine {

        Vector2 start, end;
        Color color;

    }

    struct DrawnTriangle {

        Vector2 a, b, c;
        Color color;

        bool isClose(Vector2 a, Vector2 b, Vector2 c) const
            => .isClose(a.x, this.a.x)
            && .isClose(a.y, this.a.y)
            && .isClose(b.x, this.b.x)
            && .isClose(b.y, this.b.y)
            && .isClose(c.x, this.c.x)
            && .isClose(c.y, this.c.y);


    }

    struct DrawnRectangle {

        Rectangle rectangle;
        Color color;

        alias rectangle this;

        bool isClose(Rectangle rectangle) const

            => isClose(rectangle.tupleof);

        bool isClose(float x, float y, float width, float height) const

            => .isClose(this.rectangle.x, x)
            && .isClose(this.rectangle.y, y)
            && .isClose(this.rectangle.width, width)
            && .isClose(this.rectangle.height, height);

        bool isStartClose(Vector2 start) const

            => isStartClose(start.tupleof);

        bool isStartClose(float x, float y) const

            => .isClose(this.rectangle.x, x)
            && .isClose(this.rectangle.y, y);

    }

    struct DrawnTexture {

        uint id;
        int width;
        int height;
        int dpiX;
        int dpiY;
        Vector2 position;
        Color tint;

        alias drawnRectangle this;

        this(Texture texture, Vector2 position, Color tint) {

            // Omit the "backend" Texture field to make `canvas` @safe
            this.id = texture.id;
            this.width = texture.width;
            this.height = texture.height;
            this.dpiX = texture.dpiX;
            this.dpiY = texture.dpiY;
            this.position = position;
            this.tint = tint;

        }

        Texture texture(HeadlessBackend backend) const

            => Texture(backend, id, width, height);

        DrawnRectangle drawnRectangle() const

            => DrawnRectangle(rectangle, tint);

        Rectangle rectangle() const

            => Rectangle(position.tupleof, width, height);

        alias isPositionClose = isStartClose;

        bool isStartClose(Vector2 start) const

            => isStartClose(start.tupleof);

        bool isStartClose(float x, float y) const

            => .isClose(this.position.x, x)
            && .isClose(this.position.y, y);

    }

    alias Drawing = SumType!(DrawnLine, DrawnTriangle, DrawnRectangle, DrawnTexture);

    private {

        dstring characterQueue;
        State[GluiMouseButton.max+1] mouse;
        State[GluiKeyboardKey.max+1] keyboard;
        State[GluiGamepadButton.max+1] gamepad;
        Vector2 _mousePosition;
        Vector2 _windowSize;
        Vector2 _hidpiScale;
        Rectangle _area;
        GluiMouseCursor _cursor;
        float _deltaTime = 1f / 60f;
        bool _justResized;
        bool _scissorsOn;

        /// Currently allocated/used textures as URLs.
        ///
        /// Textures loaded from images are `null` if arsd.image isn't present.
        string[uint] allocatedTextures;

        /// Last used texture ID.
        uint lastTextureID;

    }

    public {

        /// All items drawn during the last frame
        Appender!(Drawing[]) canvas;

    }

    this(Vector2 windowSize = Vector2(800, 600), Vector2 hidpiScale = Vector2(1, 1)) {

        this._windowSize = windowSize;
        this._hidpiScale = hidpiScale;

    }

    /// Switch to the next frame.
    void nextFrame(float deltaTime = 1f / 60f) {

        deltaTime = deltaTime;

        // Clear temporary data
        characterQueue = null;
        _justResized = false;
        canvas.clear();

        // Update input
        foreach (ref state; chain(mouse[], keyboard[], gamepad[])) {

            final switch (state) {

                case state.up:
                case state.down:
                    break;
                case state.pressed:
                case state.repeated:
                    state = State.down;
                    break;
                case state.released:
                    state = State.up;
                    break;


            }

        }

    }

    /// Resize the window.
    void resize(Vector2 size, Vector2 hidpiScale = Vector2(1, 1)) {

        _windowSize = size;
        _hidpiScale = hidpiScale;
        _justResized = true;

    }

    /// Press the given key, and hold it until `release`. Marks as repeated if already down.
    void press(GluiKeyboardKey key) {

        if (isDown(key))
            keyboard[key] = State.repeated;
        else
            keyboard[key] = State.pressed;

    }

    /// Release the given keyboard key.
    void release(GluiKeyboardKey key) {

        keyboard[key] = State.released;

    }

    /// Press the given button, and hold it until `release`.
    void press(GluiMouseButton button) {

        mouse[button] = State.pressed;

    }

    /// Release the given mouse button.
    void release(GluiMouseButton button) {

        mouse[button] = State.released;

    }

    /// Press the given button, and hold it until `release`.
    void press(GluiGamepadButton button) {

        gamepad[button] = State.pressed;

    }

    /// Release the given mouse button.
    void release(GluiGamepadButton button) {

        gamepad[button] = State.released;

    }

    /// Check if the given mouse button has just been pressed/released or, if it's held down or not (up).
    bool isPressed(GluiMouseButton button) const

        => mouse[button] == State.pressed;

    bool isReleased(GluiMouseButton button) const

        => mouse[button] == State.released;

    bool isDown(GluiMouseButton button) const

        => mouse[button] == State.pressed
        || mouse[button] == State.repeated
        || mouse[button] == State.down;

    bool isUp(GluiMouseButton button) const

        => mouse[button] == State.released
        || mouse[button] == State.up;

    /// Check if the given keyboard key has just been pressed/released or, if it's held down or not (up).
    bool isPressed(GluiKeyboardKey key) const

        => keyboard[key] == State.pressed;

    bool isReleased(GluiKeyboardKey key) const

        => keyboard[key] == State.released;

    bool isDown(GluiKeyboardKey key) const

        => keyboard[key] == State.pressed
        || keyboard[key] == State.repeated
        || keyboard[key] == State.down;

    bool isUp(GluiKeyboardKey key) const

        => keyboard[key] == State.released
        || keyboard[key] == State.up;

    /// If true, the given keyboard key has been virtually pressed again, through a long-press.
    bool isRepeated(GluiKeyboardKey key) const

        => keyboard[key] == State.repeated;

    /// Get next queued character from user's input. The queue should be cleared every frame. Return null if no
    /// character was pressed.
    dchar inputCharacter() {

        if (characterQueue.empty) return '\0';

        auto c = characterQueue.front;
        characterQueue.popFront;
        return c;

    }

    /// Insert a character into input queue.
    void inputCharacter(dchar character) {

        characterQueue ~= character;

    }

    /// ditto
    void inputCharacter(dstring str) {

        characterQueue ~= str;

    }

    /// Check if the given gamepad button has been pressed/released or, if it's held down or not (up).
    ///
    /// Controllers start at 0.
    bool isPressed(int controller, GluiGamepadButton button) const

        => gamepad[button] == State.pressed;

    bool isReleased(int controller, GluiGamepadButton button) const

        => gamepad[button] == State.released;

    bool isDown(int controller, GluiGamepadButton button) const

        => gamepad[button] == State.pressed
        || gamepad[button] == State.repeated
        || gamepad[button] == State.down;

    bool isUp(int controller, GluiGamepadButton button) const

        => gamepad[button] == State.released
        || gamepad[button] == State.up;

    /// Get/set mouse position
    Vector2 mousePosition(Vector2 value)

        => _mousePosition = value;

    Vector2 mousePosition() const

        => _mousePosition;

    /// Get time elapsed since last frame in seconds.
    float deltaTime() const

        => _deltaTime;

    /// True if the user has just resized the window.
    bool hasJustResized() const

        => _justResized;

    /// Get or set the size of the window.
    Vector2 windowSize(Vector2 value)

        => _windowSize = value;

    Vector2 windowSize() const

        => _windowSize;

    /// Get HiDPI scale of the window. This does nothing in the headless backend.
    Vector2 hidpiScale() const

        => _hidpiScale;

    /// Set area within the window items will be drawn to; any pixel drawn outside will be discarded.
    Rectangle area(Rectangle rect) {

        _scissorsOn = true;
        return _area = rect;

    }

    Rectangle area() const

        => _scissorsOn ? _area : Rectangle(0, 0, _windowSize.tupleof);

    /// Restore the capability to draw anywhere in the window.
    void restoreArea() {

        _scissorsOn = false;

    }

    /// Get or set mouse cursor icon.
    GluiMouseCursor mouseCursor(GluiMouseCursor cursor)

        => _cursor = cursor;

    GluiMouseCursor mouseCursor() const

        => _cursor;

    Texture loadTexture(Image image) @system {

        // It's probably desirable to have this toggleable at class level
        static if (svgTextures) {

            import std.base64;
            import arsd.png;
            import arsd.image;

            // Load the image
            auto data = cast(ubyte[]) image.pixels;
            auto arsdImage = new TrueColorImage(image.width, image.height, data);

            // Encode as a PNG in a data URL
            auto png = arsdImage.writePngToArray();
            auto base64 = Base64.encode(png);
            auto url = format!"data:image/png;base64,%s"(base64);

            // Convert to a Glui image
            return loadTexture(url, arsdImage.width, arsdImage.height);

        }

        // Can't load the texture, pretend to load a 16px texture
        else return loadTexture(null, image.width, image.height);

    }

    Texture loadTexture(string filename) @system {

        static if (svgTextures) {

            import std.uri : encodeURI = encode;
            import std.path;
            import arsd.image;

            // Load the image to check its size
            auto image = loadImageFromFile(filename);
            auto url = format!"file:///%s"(filename.absolutePath.encodeURI);

            return loadTexture(url, image.width, image.height);

        }

        // Can't load the texture, pretend to load a 16px texture
        else return loadTexture(null, 16, 16);

    }

    Texture loadTexture(string url, int width, int height) {

        Texture texture;
        texture.backend = this;
        texture.id = ++lastTextureID;
        texture.width = width;
        texture.height = height;

        // Allocate the texture
        allocatedTextures[texture.id] = url;

        return texture;

    }

    /// Destroy a texture created by this backend. `texture.destroy()` is the preferred way of calling this, since it
    /// will ensure the correct backend is called.
    void unloadTexture(Texture texture) @system {

        const found = texture.id in allocatedTextures;

        assert(found, format!"headless: Attempted to free nonexistent texture %s"(texture));

        allocatedTextures.remove(texture.id);

    }

    /// Draw a line.
    void drawLine(Vector2 start, Vector2 end, Color color) {

        canvas ~= Drawing(DrawnLine(start, end, color));

    }

    /// Draw a triangle, consisting of 3 vertices with counter-clockwise winding.
    void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) {

        canvas ~= Drawing(DrawnTriangle(a, b, c, color));

    }

    /// Draw a rectangle.
    void drawRectangle(Rectangle rectangle, Color color) {

        canvas ~= Drawing(DrawnRectangle(rectangle, color));

    }

    /// Draw a texture.
    void drawTexture(Texture texture, Vector2 position, Color tint)
    in (false)
    do {

        canvas ~= Drawing(DrawnTexture(texture, position, tint));

    }

    /// Get items from the canvas that match the given type.
    auto filterCanvas(T)()

        => canvas[]

        // Filter out items that don't match what was requested
        .filter!(a => a.match!(
            (T item) => true,
            (_) => false
        ))

        // Return items that match
        .map!(a => a.match!(
            (T item) => item,
            (_) => assert(false),
        ));

    alias lines = filterCanvas!DrawnLine;
    alias triangles = filterCanvas!DrawnTriangle;
    alias rectangles = filterCanvas!DrawnRectangle;
    alias textures = filterCanvas!DrawnTexture;

    /// Throw an `AssertError` if given triangle was never drawn.
    void assertTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) {

        assert(
            triangles.canFind!(trig => trig.isClose(a, b, c) && trig.color == color),
            "No matching triangle"
        );

    }

    /// Throw an `AssertError` if given rectangle was never drawn.
    void assertRectangle(Rectangle r, Color color) {

        assert(
            rectangles.canFind!(rect => rect.isClose(r) && rect.color == color),
            "No matching rectangle"
        );

    }

    /// Throw an `AssertError` if the texture was never drawn with given parameters.
    void assertTexture(const Texture texture, Vector2 position, Color tint) {

        assert(texture.backend is this, "Given texture comes from a different backend");
        assert(
            textures.canFind!(tex
                => tex.id == texture.id
                && tex.width == texture.width
                && tex.height == texture.height
                && tex.dpiX == texture.dpiX
                && tex.dpiY == texture.dpiY
                && tex.isPositionClose(position)
                && tex.tint == tint),
            "No matching texture"
        );

    }

    /// Throw an `AssertError` if given texture was never drawn.
    void assertTexture(Rectangle r, Color color) {

        assert(
            textures.canFind!(rect => rect.isClose(r) && rect.color == color),
            "No matching texture"
        );

    }

    version (Have_elemi) {

        import std.conv;
        import elemi.xml;

        /// Convert the canvas to SVG. Intended for debugging only.
        ///
        /// `toSVG` provides the document as a string (including the XML prolog), `toSVGElement` provides a Glui element
        /// (without the prolog) and `saveSVG` saves it to a file.
        ///
        /// Note that rendering textures and text is only done if arsd.image is available. Otherwise, they will display
        /// as rectangles filled with whatever tint color was set. Text, if rendered, is rasterized, because it occurs
        /// earlier in the pipeline, and is not available to the backend.
        void saveSVG(string filename) const {

            import std.file : write;

            write(filename, toSVG);

        }

        /// ditto
        string toSVG() const

            => Element.XMLDeclaration1_0 ~ this.toSVGElement;

        /// ditto
        Element toSVGElement() const {

            /// Colors available as tint filters in the document.
            bool[Color] tints;

            /// Generate a tint filter for the given color
            Element useTint(Color color) {

                // Ignore if the given filter already exists
                if (color in tints) return elems();

                tints[color] = true;

                // <pain>
                return elem!"filter"(

                    // Use the color as the filter ID, prefixed with "t" instead of "#"
                    attr("id") = color.toHex!"t",

                    // Create a layer full of that color
                    elem!"feFlood"(
                        attr("x") = "0",
                        attr("y") = "0",
                        attr("width") = "100%",
                        attr("height") = "100%",
                        attr("flood-color") = color.toHex,
                    ),

                    // Blend in with the original image
                    elem!"feBlend"(
                        attr("in2") = "SourceGraphic",
                        attr("mode") = "multiply",
                    ),

                    // Use the source image for opacity
                    elem!"feComposite"(
                        attr("in2") = "SourceGraphic",
                        attr("operator") = "in",
                    ),

                );
                // </pain>

            }

            return elem!"svg"(
                attr("xmlns") = "http://www.w3.org/2000/svg",
                attr("version") = "1.1",
                attr("width") = text(cast(int) windowSize.x),
                attr("height") = text(cast(int) windowSize.y),

                canvas[].map!(a => a.match!(
                    (DrawnLine line) => elem!"line"(
                        attr("x1") = line.start.x.text,
                        attr("y1") = line.start.y.text,
                        attr("x2") = line.end.x.text,
                        attr("y2") = line.end.y.text,
                        attr("stroke") = line.color.toHex,
                    ),
                    (DrawnTriangle trig) => elem!"polygon"(
                        attr("points") = [
                            format!"%s,%s"(trig.a.tupleof),
                            format!"%s,%s"(trig.b.tupleof),
                            format!"%s,%s"(trig.c.tupleof),
                        ],
                        attr("fill") = trig.color.toHex,
                    ),
                    (DrawnTexture texture) {

                        auto url = texture.id in allocatedTextures;

                        // URL given, valid image
                        if (url && *url)
                            return elems(
                                useTint(texture.tint),
                                elem!"image"(
                                    attr("x") = texture.position.x.text,
                                    attr("y") = texture.position.y.text,
                                    attr("width") = texture.width.text,
                                    attr("height") = texture.height.text,
                                    attr("href") = *url,
                                    attr("style") = format!"filter:url(#%s)"(texture.tint.toHex!"t"),
                                ),
                            );

                        // No image, draw a placeholder rect
                        else
                            return elem!"rect"(
                                attr("x") = texture.position.x.text,
                                attr("y") = texture.position.y.text,
                                attr("width") = texture.width.text,
                                attr("height") = texture.height.text,
                                attr("fill") = texture.tint.toHex,
                            );

                    },
                    (DrawnRectangle rect) => elem!"rect"(
                        attr("x") = rect.x.text,
                        attr("y") = rect.y.text,
                        attr("width") = rect.width.text,
                        attr("height") = rect.height.text,
                        attr("fill") = rect.color.toHex,
                    ),
                ))
            );

        }

    }

}

unittest {

    auto backend = new HeadlessBackend(Vector2(800, 600));

    with (backend) {

        press(GluiMouseButton.left);

        assert(isPressed(GluiMouseButton.left));
        assert(isDown(GluiMouseButton.left));
        assert(!isUp(GluiMouseButton.left));
        assert(!isReleased(GluiMouseButton.left));

        press(GluiKeyboardKey.enter);

        assert(isPressed(GluiKeyboardKey.enter));
        assert(isDown(GluiKeyboardKey.enter));
        assert(!isUp(GluiKeyboardKey.enter));
        assert(!isReleased(GluiKeyboardKey.enter));
        assert(!isRepeated(GluiKeyboardKey.enter));

        nextFrame;

        assert(!isPressed(GluiMouseButton.left));
        assert(isDown(GluiMouseButton.left));
        assert(!isUp(GluiMouseButton.left));
        assert(!isReleased(GluiMouseButton.left));

        assert(!isPressed(GluiKeyboardKey.enter));
        assert(isDown(GluiKeyboardKey.enter));
        assert(!isUp(GluiKeyboardKey.enter));
        assert(!isReleased(GluiKeyboardKey.enter));
        assert(!isRepeated(GluiKeyboardKey.enter));

        nextFrame;

        press(GluiKeyboardKey.enter);

        assert(!isPressed(GluiKeyboardKey.enter));
        assert(isDown(GluiKeyboardKey.enter));
        assert(!isUp(GluiKeyboardKey.enter));
        assert(!isReleased(GluiKeyboardKey.enter));
        assert(isRepeated(GluiKeyboardKey.enter));

        nextFrame;

        release(GluiMouseButton.left);

        assert(!isPressed(GluiMouseButton.left));
        assert(!isDown(GluiMouseButton.left));
        assert(isUp(GluiMouseButton.left));
        assert(isReleased(GluiMouseButton.left));

        release(GluiKeyboardKey.enter);

        assert(!isPressed(GluiKeyboardKey.enter));
        assert(!isDown(GluiKeyboardKey.enter));
        assert(isUp(GluiKeyboardKey.enter));
        assert(isReleased(GluiKeyboardKey.enter));
        assert(!isRepeated(GluiKeyboardKey.enter));

        nextFrame;

        assert(!isPressed(GluiMouseButton.left));
        assert(!isDown(GluiMouseButton.left));
        assert(isUp(GluiMouseButton.left));
        assert(!isReleased(GluiMouseButton.left));

        assert(!isPressed(GluiKeyboardKey.enter));
        assert(!isDown(GluiKeyboardKey.enter));
        assert(isUp(GluiKeyboardKey.enter));
        assert(!isReleased(GluiKeyboardKey.enter));
        assert(!isRepeated(GluiKeyboardKey.enter));

    }

}
