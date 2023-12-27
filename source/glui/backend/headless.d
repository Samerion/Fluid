module glui.backend.headless;

debug (Glui_BuildMessages) {
    pragma(msg, "Glui: Building with headless backend");
}

import std.array;
import std.range;
import std.string;
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

    }

    struct DrawnRectangle {

        Rectangle rectangle;
        Color color;

    }

    struct DrawnTexture {

        Texture texture;
        Vector2 position;
        Color color;

    }

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

        Appender!(DrawnLine[]) lines;
        Appender!(DrawnTriangle[]) triangles;
        Appender!(DrawnRectangle[]) rectangles;
        Appender!(DrawnTexture[]) textures;

    }

    this(Vector2 windowSize, Vector2 hidpiScale = Vector2(1, 1)) {

        this._windowSize = windowSize;
        this._hidpiScale = hidpiScale;

    }

    /// Switch to the next frame.
    void nextFrame(float deltaTime = 1f / 60f) {

        deltaTime = deltaTime;

        // Clear temporary data
        characterQueue = null;
        _justResized = false;

        // Clear the "canvas"
        lines.clear();
        triangles.clear();
        rectangles.clear();
        textures.clear();

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

        => mouse[key] == State.pressed;

    bool isReleased(GluiKeyboardKey key) const

        => mouse[key] == State.released;

    bool isDown(GluiKeyboardKey key) const

        => mouse[key] == State.pressed
        || mouse[key] == State.repeated
        || mouse[key] == State.down;

    bool isUp(GluiKeyboardKey key) const

        => mouse[key] == State.released
        || mouse[key] == State.up;

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

        lines ~= DrawnLine(start, end, color);

    }

    /// Draw a triangle, consisting of 3 vertices with counter-clockwise winding.
    void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) {

        triangles ~= DrawnTriangle(a, b, c, color);

    }

    /// Draw a rectangle.
    void drawRectangle(Rectangle rectangle, Color color) {

        rectangles ~= DrawnRectangle(rectangle, color);

    }

    /// Draw a texture.
    void drawTexture(Texture texture, Vector2 position, Color tint) {

        textures ~= DrawnTexture(texture, position, tint);

    }

}
