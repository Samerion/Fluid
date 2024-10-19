/// A headless backend. This backend does not actually render anything. This allows apps reliant on Fluid to run 
/// outside of graphical environments, provided an alternative method of access exist.
///
/// This backend is used internally in Fluid for performing tests. For this reason, this module may be configured to 
/// capture the output in a way that can be analyzed or compared againt later. This functionality is disabled by 
/// default due to significant overhead — use version `Fluid_HeadlessOutput` to turn it on.
///
/// If `elemi` is added as a dependency and `Fluid_HeadlessOutput` is set, the backend will also expose its 
/// experimental SVG export functionality through `saveSVG`. It is only intended for testing; note it will export text 
/// as embedded raster images rather than proper vector text.
module fluid.backend.headless;

debug (Fluid_BuildMessages) {
    pragma(msg, "Fluid: Building with headless backend");
}

import std.math;
import std.array;
import std.range;
import std.string;
import std.algorithm;

import fluid.backend;

version (Fluid_HeadlessOutput) {
    import std.sumtype;
}


@safe:


/// Rendering textures in SVG requires arsd.image
version (Have_arsd_official_image_files)
    enum svgTextures = true;
else
    enum svgTextures = false;

debug (Fluid_BuildMessages) {
    pragma(msg, "Fluid: SVG output support " ~ (svgTextures ? "ON" : "OFF"));
}

class HeadlessBackend : FluidBackend {

    enum defaultWindowSize = Vector2(800, 600);

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

        bool isClose(Vector2 a, Vector2 b) const {
            return (
                .isClose(start.x, this.start.x)
                && .isClose(start.y, this.start.y)
                && .isClose(end.x, this.end.x)
                && .isClose(end.y, this.end.y))
            || (
                .isClose(end.x, this.end.x)
                && .isClose(end.y, this.end.y)
                && .isClose(start.x, this.start.x)
                && .isClose(start.y, this.start.y));
        }

    }

    struct DrawnTriangle {

        Vector2 a, b, c;
        Color color;

        bool isClose(Vector2 a, Vector2 b, Vector2 c) const {
            return .isClose(a.x, this.a.x)
                && .isClose(a.y, this.a.y)
                && .isClose(b.x, this.b.x)
                && .isClose(b.y, this.b.y)
                && .isClose(c.x, this.c.x)
                && .isClose(c.y, this.c.y);
        }

    }

    struct DrawnCircle {

        Vector2 position;
        float radius;
        Color color;
        bool outlineOnly;

        bool isClose(Vector2 position, float radius) const {
            return .isClose(position.x, this.position.x)
                && .isClose(position.y, this.position.y)
                && .isClose(radius, this.radius);
        }

    }

    struct DrawnRectangle {

        Rectangle rectangle;
        Color color;

        alias rectangle this;

        bool isClose(Rectangle rectangle) const {
            return isClose(rectangle.tupleof);
        }

        bool isClose(float x, float y, float width, float height) const {
            return .isClose(this.rectangle.x, x)
                && .isClose(this.rectangle.y, y)
                && .isClose(this.rectangle.width, width)
                && .isClose(this.rectangle.height, height);
        }

        bool isStartClose(Vector2 start) const {
            return isStartClose(start.tupleof);
        }

        bool isStartClose(float x, float y) const {
            return .isClose(this.rectangle.x, x)
                && .isClose(this.rectangle.y, y);
        }

    }

    struct DrawnTexture {

        uint id;
        int width;
        int height;
        int dpiX;
        int dpiY;
        Rectangle rectangle;
        Color tint;

        alias drawnRectangle this;

        this(Texture texture, Rectangle rectangle, Color tint) {

            // Omit the "backend" Texture field to make `canvas` @safe
            this.id = texture.id;
            this.width = texture.width;
            this.height = texture.height;
            this.dpiX = texture.dpiX;
            this.dpiY = texture.dpiY;
            this.rectangle = rectangle;
            this.tint = tint;

        }

        Vector2 position() const {
            return Vector2(rectangle.x, rectangle.y);
        }

        DrawnRectangle drawnRectangle() const {
            return DrawnRectangle(rectangle, tint);
        }

        alias isPositionClose = isStartClose;

        bool isStartClose(Vector2 start) const {
            return isStartClose(start.tupleof);
        }

        bool isStartClose(float x, float y) const {
            return .isClose(rectangle.x, x)
                && .isClose(rectangle.y, y);
        }

    }

    version (Fluid_HeadlessOutput) {
    
        alias Drawing = SumType!(DrawnLine, DrawnTriangle, DrawnCircle, DrawnRectangle, DrawnTexture);

        /// All items drawn during the last frame
        Appender!(Drawing[]) canvas;

    }

    private {

        dstring characterQueue;
        State[MouseButton.max+1] mouse;
        State[KeyboardKey.max+1] keyboard;
        State[GamepadButton.max+1] gamepad;
        Vector2 _scroll;
        Vector2 _mousePosition;
        Vector2 _windowSize;
        Vector2 _dpi = Vector2(96, 96);
        float _scale = 1;
        Rectangle _area;
        FluidMouseCursor _cursor;
        float _deltaTime = 1f / 60f;
        bool _justResized;
        bool _scissorsOn;
        Color _tint = Color(0xff, 0xff, 0xff, 0xff);
        string _clipboard;

        /// Currently allocated/used textures as URLs.
        ///
        /// Textures loaded from images are `null` if arsd.image isn't present.
        string[uint] allocatedTextures;

        /// Texture reaper.
        TextureReaper _reaper;

        /// Last used texture ID.
        uint lastTextureID;

    }

    this(Vector2 windowSize = defaultWindowSize) {

        this._windowSize = windowSize;

    }

    /// Switch to the next frame.
    void nextFrame(float deltaTime = 1f / 60f) {

        deltaTime = deltaTime;

        // Clear temporary data
        characterQueue = null;
        _justResized = false;
        _scroll = Vector2();

        version (Fluid_HeadlessOutput) {
            canvas.clear();
        }

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
    void resize(Vector2 size) {

        _windowSize = size;
        _justResized = true;

    }

    /// Press the given key, and hold it until `release`. Marks as repeated if already down.
    void press(KeyboardKey key) {

        if (isDown(key))
            keyboard[key] = State.repeated;
        else
            keyboard[key] = State.pressed;

    }

    /// Release the given keyboard key.
    void release(KeyboardKey key) {

        keyboard[key] = State.released;

    }

    /// Press the given button, and hold it until `release`.
    void press(MouseButton button = MouseButton.left) {

        mouse[button] = State.pressed;

    }

    /// Release the given mouse button.
    void release(MouseButton button = MouseButton.left) {

        mouse[button] = State.released;

    }

    /// Press the given button, and hold it until `release`.
    void press(GamepadButton button) {

        gamepad[button] = State.pressed;

    }

    /// Release the given mouse button.
    void release(GamepadButton button) {

        gamepad[button] = State.released;

    }

    /// Check if the given mouse button has just been pressed/released or, if it's held down or not (up).
    bool isPressed(MouseButton button) const {
         return mouse[button] == State.pressed;
    }

    bool isReleased(MouseButton button) const {
        return mouse[button] == State.released;
    }

    bool isDown(MouseButton button) const {
        return mouse[button] == State.pressed
            || mouse[button] == State.repeated
            || mouse[button] == State.down;
    }

    bool isUp(MouseButton button) const {
        return mouse[button] == State.released
            || mouse[button] == State.up;
    }

    /// Check if the given keyboard key has just been pressed/released or, if it's held down or not (up).
    bool isPressed(KeyboardKey key) const {
        return keyboard[key] == State.pressed;
    }

    bool isReleased(KeyboardKey key) const {
        return keyboard[key] == State.released;
    }

    bool isDown(KeyboardKey key) const {
        return keyboard[key] == State.pressed
            || keyboard[key] == State.repeated
            || keyboard[key] == State.down;
    }

    bool isUp(KeyboardKey key) const {
        return keyboard[key] == State.released
            || keyboard[key] == State.up;
    }

    /// If true, the given keyboard key has been virtually pressed again, through a long-press.
    bool isRepeated(KeyboardKey key) const {
        return keyboard[key] == State.repeated;
    }

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
    int isPressed(GamepadButton button) const {
		return gamepad[button] == State.pressed;
	}

	int isReleased(GamepadButton button) const {
		return gamepad[button] == State.released;
	}

	int isDown(GamepadButton button) const {
		return gamepad[button] == State.pressed
			|| gamepad[button] == State.repeated
			|| gamepad[button] == State.down;
	}

    int isUp(GamepadButton button) const {
        return gamepad[button] == State.released
            || gamepad[button] == State.up;
    }

    int isRepeated(GamepadButton button) const {
        return gamepad[button] == State.repeated;
    }

    /// Get/set mouse position
    Vector2 mousePosition(Vector2 value) {
        return _mousePosition = value;}

    Vector2 mousePosition() const {
        return _mousePosition;
    }

    /// Get/set mouse scroll
    Vector2 scroll(Vector2 value) {
        return _scroll = scroll;
    }

    Vector2 scroll() const {
        return _scroll;
    }

    string clipboard(string value) @trusted {
        return _clipboard = value;
    }

    string clipboard() const @trusted {
        return _clipboard;
    }

    /// Get time elapsed since last frame in seconds.
    float deltaTime() const {
        return _deltaTime;
    }

    /// True if the user has just resized the window.
    bool hasJustResized() const {
        return _justResized;
    }

    /// Get or set the size of the window.
    Vector2 windowSize(Vector2 value) {
        resize(value);
        return value;
    }

    Vector2 windowSize() const {
        return _windowSize;
    }

    float scale() const {
        return _scale;
    }

    float scale(float value) {
        return _scale = value;
    }

    /// Get HiDPI scale of the window. This is not currently supported by this backend.
    Vector2 dpi() const {
        return _dpi * _scale;
    }

    /// Set area within the window items will be drawn to; any pixel drawn outside will be discarded.
    Rectangle area(Rectangle rect) {
        _scissorsOn = true;
        return _area = rect;
    }

    Rectangle area() const {

        if (_scissorsOn) 
            return _area;
        else
            return Rectangle(0, 0, _windowSize.tupleof);
    }

    /// Restore the capability to draw anywhere in the window.
    void restoreArea() {
        _scissorsOn = false;
    }

    /// Get or set mouse cursor icon.
    FluidMouseCursor mouseCursor(FluidMouseCursor cursor) {
        return _cursor = cursor;
    }

    FluidMouseCursor mouseCursor() const {
        return _cursor;
    }

    TextureReaper* reaper() return scope {

        return &_reaper;

    }

    Texture loadTexture(Image image) @system {

        auto texture = loadTexture(null, image.width, image.height);
        texture.format = image.format;

        // Fill the texture with data
        updateTexture(texture, image);

        return texture;

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
        texture.id = ++lastTextureID;
        texture.tombstone = reaper.makeTombstone(this, texture.id);
        texture.width = width;
        texture.height = height;

        // Allocate the texture
        allocatedTextures[texture.id] = url;

        return texture;

    }

    void updateTexture(Texture texture, Image image) @system
    in (false)
    do {

        static if (svgTextures) {

            import std.base64;
            import arsd.png;
            import arsd.image;

            ubyte[] data;

            // Load the image
            final switch (image.format) {

                case Image.Format.rgba:
                    data = cast(ubyte[]) image.rgbaPixels;
                    break;

                // At the moment, this loads the palette available at the time of generation.
                // Could it be possible to update the palette later?
                case Image.Format.palettedAlpha:
                    data = cast(ubyte[]) image.palettedAlphaPixels
                        .map!(a => image.paletteColor(a))
                        .array;
                    break;

                case Image.Format.alpha:
                    data = cast(ubyte[]) image.alphaPixels
                        .map!(a => Color(0xff, 0xff, 0xff, a))
                        .array;
                    break;

            }

            // Load the image
            auto arsdImage = new TrueColorImage(image.width, image.height, data);

            // Encode as a PNG in a data URL
            auto png = arsdImage.writePngToArray();
            auto base64 = Base64.encode(png);
            auto url = format!"data:image/png;base64,%s"(base64);

            // Set the URL
            allocatedTextures[texture.id] = url;

        }

        else
            allocatedTextures[texture.id] = null;

    }

    /// Destroy a texture created by this backend. `texture.destroy()` is the preferred way of calling this, since it
    /// will ensure the correct backend is called.
    void unloadTexture(uint id) @system {

        const found = id in allocatedTextures;

        assert(found, format!"headless: Attempted to free nonexistent texture ID %s (double free?)"(id));

        allocatedTextures.remove(id);

    }

    /// Check if the given texture has a valid ID
    bool isTextureValid(Texture texture) {

        return cast(bool) (texture.id in allocatedTextures);

    }

    bool isTextureValid(uint id) {

        return cast(bool) (id in allocatedTextures);

    }

    Color tint(Color color) {

        return _tint = color;

    }

    Color tint() const {

        return _tint;

    }

    /// Draw a line.
    void drawLine(Vector2 start, Vector2 end, Color color) {

        color = multiply(color, tint);

        version (Fluid_HeadlessOutput) {
            canvas ~= Drawing(DrawnLine(start, end, color));
        }

    }

    /// Draw a triangle, consisting of 3 vertices with counter-clockwise winding.
    void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) {

        color = multiply(color, tint);
        version (Fluid_HeadlessOutput) {
            canvas ~= Drawing(DrawnTriangle(a, b, c, color));
        }

    }

    /// Draw a circle.
    void drawCircle(Vector2 position, float radius, Color color) {

        color = multiply(color, tint);
        version (Fluid_HeadlessOutput) {
            canvas ~= Drawing(DrawnCircle(position, radius, color));
        }

    }

    /// Draw a circle, but outline only.
    void drawCircleOutline(Vector2 position, float radius, Color color) {

        color = multiply(color, tint);
        version (Fluid_HeadlessOutput) {
            canvas ~= Drawing(DrawnCircle(position, radius, color, true));
        }

    }

    /// Draw a rectangle.
    void drawRectangle(Rectangle rectangle, Color color) {

        color = multiply(color, tint);
        version (Fluid_HeadlessOutput) {
            canvas ~= Drawing(DrawnRectangle(rectangle, color));
        }

    }

    /// Draw a texture.
    void drawTexture(Texture texture, Rectangle rectangle, Color tint)
    in (false)
    do {

        tint = multiply(tint, this.tint);
        version (Fluid_HeadlessOutput) {
            canvas ~= Drawing(DrawnTexture(texture, rectangle, tint));
        }

    }

    /// Draw a texture, but keep it aligned to pixel boundaries.
    void drawTextureAlign(Texture texture, Rectangle rectangle, Color tint)
    in (false)
    do {

        drawTexture(texture, rectangle, tint);

    }

    /// Get items from the canvas that match the given type.
    version (Fluid_HeadlessOutput) {

        auto filterCanvas(T)() {

            return canvas[]

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

        }

        alias lines = filterCanvas!DrawnLine;
        alias triangles = filterCanvas!DrawnTriangle;
        alias rectangles = filterCanvas!DrawnRectangle;
        alias textures = filterCanvas!DrawnTexture;

    }

    /// Throw an `AssertError` if given line was never drawn.
    version (Fluid_HeadlessOutput)
    void assertLine(Vector2 a, Vector2 b, Color color) {

        assert(
            lines.canFind!(line => line.isClose(a, b) && line.color == color),
            "No matching line"
        );

    }

    /// Throw an `AssertError` if given triangle was never drawn.
    version (Fluid_HeadlessOutput)
    void assertTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) {

        assert(
            triangles.canFind!(trig => trig.isClose(a, b, c) && trig.color == color),
            "No matching triangle"
        );

    }

    /// Throw an `AssertError` if given rectangle was never drawn.
    version (Fluid_HeadlessOutput)
    void assertRectangle(Rectangle r, Color color) {

        assert(
            rectangles.canFind!(rect => rect.isClose(r) && rect.color == color),
            format!"No rectangle matching %s %s"(r, color)
        );

    }

    /// Throw an `AssertError` if the texture was never drawn with given parameters.
    version (Fluid_HeadlessOutput)
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
    version (Fluid_HeadlessOutput)
    void assertTexture(Rectangle r, Color color) {

        assert(
            textures.canFind!(rect => rect.isClose(r) && rect.color == color),
            "No matching texture"
        );

    }

    version (Fluid_HeadlessOutput)
    version (Have_elemi) {

        import std.conv;
        import elemi.xml;

        /// Convert the canvas to SVG. Intended for debugging only.
        ///
        /// `toSVG` provides the document as a string (including the XML prolog), `toSVGElement` provides a Fluid element
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
        string toSVG() const {
            return Element.XMLDeclaration1_0 ~ this.toSVGElement;
        }

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
                attr("style") = "background: #000",

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
                    (DrawnCircle circle) => elems(), // TODO
                    (DrawnTexture texture) {

                        auto url = texture.id in allocatedTextures;

                        // URL given, valid image
                        if (url && *url)
                            return elems(
                                useTint(texture.tint),
                                elem!"image"(
                                    attr("x") = texture.rectangle.x.text,
                                    attr("y") = texture.rectangle.y.text,
                                    attr("width") = texture.rectangle.width.text,
                                    attr("height") = texture.rectangle.height.text,
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

        press(MouseButton.left);

        assert(isPressed(MouseButton.left));
        assert(isDown(MouseButton.left));
        assert(!isUp(MouseButton.left));
        assert(!isReleased(MouseButton.left));

        press(KeyboardKey.enter);

        assert(isPressed(KeyboardKey.enter));
        assert(isDown(KeyboardKey.enter));
        assert(!isUp(KeyboardKey.enter));
        assert(!isReleased(KeyboardKey.enter));
        assert(!isRepeated(KeyboardKey.enter));

        nextFrame;

        assert(!isPressed(MouseButton.left));
        assert(isDown(MouseButton.left));
        assert(!isUp(MouseButton.left));
        assert(!isReleased(MouseButton.left));

        assert(!isPressed(KeyboardKey.enter));
        assert(isDown(KeyboardKey.enter));
        assert(!isUp(KeyboardKey.enter));
        assert(!isReleased(KeyboardKey.enter));
        assert(!isRepeated(KeyboardKey.enter));

        nextFrame;

        press(KeyboardKey.enter);

        assert(!isPressed(KeyboardKey.enter));
        assert(isDown(KeyboardKey.enter));
        assert(!isUp(KeyboardKey.enter));
        assert(!isReleased(KeyboardKey.enter));
        assert(isRepeated(KeyboardKey.enter));

        nextFrame;

        release(MouseButton.left);

        assert(!isPressed(MouseButton.left));
        assert(!isDown(MouseButton.left));
        assert(isUp(MouseButton.left));
        assert(isReleased(MouseButton.left));

        release(KeyboardKey.enter);

        assert(!isPressed(KeyboardKey.enter));
        assert(!isDown(KeyboardKey.enter));
        assert(isUp(KeyboardKey.enter));
        assert(isReleased(KeyboardKey.enter));
        assert(!isRepeated(KeyboardKey.enter));

        nextFrame;

        assert(!isPressed(MouseButton.left));
        assert(!isDown(MouseButton.left));
        assert(isUp(MouseButton.left));
        assert(!isReleased(MouseButton.left));

        assert(!isPressed(KeyboardKey.enter));
        assert(!isDown(KeyboardKey.enter));
        assert(isUp(KeyboardKey.enter));
        assert(!isReleased(KeyboardKey.enter));
        assert(!isRepeated(KeyboardKey.enter));

    }

}

/// std.math.isClose adjusted for the most common use-case.
private bool isClose(float a, float b) {

    return std.math.isClose(a, b, 0.0, 0.05);

}

unittest {

    assert(isClose(1, 1));
    assert(isClose(1.004, 1));
    assert(isClose(1.01, 1.008));
    assert(isClose(1.02, 1));
    assert(isClose(1.01, 1.03));

    assert(!isClose(1, 2));
    assert(!isClose(1, 1.1));

}
