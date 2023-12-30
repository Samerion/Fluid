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
        Vector2 position;
        Color tint;

        alias drawnRectangle this;

        this(Texture texture, Vector2 position, Color tint) {

            // Omit the "backend" Texture field to make `canvas` @safe
            this.tupleof[0..3] = texture.tupleof[1..4];
            this.position = position;
            this.tint = tint;

        }

        Texture texture(HeadlessBackend backend) const

            => Texture(backend, id, width, height);

        DrawnRectangle drawnRectangle() const

            => DrawnRectangle(rectangle, tint);

        Rectangle rectangle() const

            => Rectangle(position.tupleof, width, height);

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

        /// IDs used for textures.
        uint[] allocatedTextures;

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

    /// Get HiDPI scale of the window. A value of 1 should be equivalent to 96 DPI.
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

    /// Load a texture from memory or file.
    Texture loadTexture(Image image) @system {

        Texture texture;
        texture.backend = this;
        texture.id = ++lastTextureID;
        texture.width = image.width;
        texture.height = image.height;

        allocatedTextures ~= texture.id;

        return texture;

    }

    /// Dummy function: does NOT load any textures.
    Texture loadTexture(string filename) @system {

        Image image;
        image.width = 100;
        image.height = 100;

        return loadTexture(image);

    }

    /// Destroy a texture created by this backend. `texture.destroy()` is the preferred way of calling this, since it
    /// will ensure the correct backend is called.
    void unloadTexture(Texture texture) @system {

        auto index = allocatedTextures.countUntil(texture.id);

        assert(index != -1, format!"headless: Attempted to free nonexistent texture %s"(texture));

        allocatedTextures = allocatedTextures.remove(index);

    }

    // TODO make these store data

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
    void drawTexture(Texture texture, Vector2 position, Color tint) {

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
        /// Note that rendering textures and text is NOT implemented. They will render as rectangles instead with
        /// whatever tint color they have been assigned.
        string toSVG() const

            => Element.XMLDeclaration1_0 ~ this.toSVGElement;

        /// ditto
        Element toSVGElement() const

            => elem!"svg"(
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
                    (DrawnTexture texture) => elem!"rect"(
                        attr("x") = texture.position.x.text,
                        attr("y") = texture.position.y.text,
                        attr("width") = texture.width.text,
                        attr("height") = texture.height.text,
                        attr("fill") = texture.tint.toHex,
                        // TODO draw the texture?
                    ),
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
