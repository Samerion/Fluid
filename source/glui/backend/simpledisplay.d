module glui.backend.simpledisplay;

version (Have_arsd_official_simpledisplay):

debug (Glui_BuildMessages) {
    pragma(msg, "Glui: Building with arsd.simpledisplay support");
}

import arsd.simpledisplay;

import std.algorithm;
import std.datetime.stopwatch;

import glui.backend;


@safe:


private {
    alias Rectangle = glui.backend.Rectangle;
    alias Color = glui.backend.Color;
    alias Image = glui.backend.Image;
}

class SimpledisplayBackend : GluiBackend {

    SimpleWindow window;

    private enum InputState {
        up,
        pressed,
        down,
        released,
        repeated,
    }

    private {

        Vector2 _mousePosition;
        int _dpi;
        float _scale = 1;
        bool _hasJustResized;
        StopWatch _stopWatch;
        float _deltaTime;
        Rectangle _scissors;
        bool _scissorsEnabled;
        GluiMouseCursor _cursor;

        /// Recent input events for each keyboard and mouse.
        InputState[GluiKeyboardKey.max+1] _keyboardState;
        InputState[GluiMouseButton.max+1] _mouseState;
        // gamepads?

        /// Characters typed by the user, awaiting consumption.
        const(dchar)[] _characterQueue;

        // Missing from simpledisplay at the time of writing
        extern(C) void function(GLint x, GLint y, GLsizei width, GLsizei height) glScissor;

    }

    // TODO HiDPI
    // TODO non-openGL backend, maybe...

    /// Initialize the backend using the given window.
    ///
    /// Make sure to call `SimpledisplayBackend.poll()` *after* the Glui `draw` call, and only do it once per frame,
    /// other Glui might not be able to keep itself up to date with latest events.
    ///
    /// Please note Glui will register its own event handlers, so if you
    /// intend to use them, you should make sure to call whatever value was set previously.
    ///
    /// ---
    /// auto oldMouseHandler = window.handleMouseEvent;
    /// window.handleMouseEvent = (MouseEvent event) {
    ///     oldMouseHandler(event);
    ///     // ... do your stuff ...
    /// };
    /// ---
    ///
    /// Gamepad input is not supported for simpledisplay.
    this(SimpleWindow window) {

        this.window = window;

        () @trusted {
            this.glScissor = cast(typeof(glScissor)) glbindGetProcAddress("glScissor");
        }();

        updateDPI();
        _stopWatch.start();

        auto oldMouseHandler = window.handleMouseEvent;
        auto oldKeyHandler = window.handleKeyEvent;
        auto oldCharHandler = window.handleCharEvent;
        auto oldWindowResized = window.windowResized;
        auto oldOnDpiChanged = window.onDpiChanged;

        // Register a mouse handler
        this.window.handleMouseEvent = (MouseEvent event) {

            if (oldMouseHandler) oldMouseHandler(event);

            final switch (event.type) {

                // Update mouse position
                case event.type.motion:
                    _mousePosition = Vector2(event.x, event.y);
                    return;

                // Update button state
                case event.type.buttonPressed:
                    _mouseState[event.button.toGlui] = InputState.pressed;
                    return;

                case event.type.buttonReleased:
                    _mouseState[event.button.toGlui] = InputState.released;
                    return;

            }

        };

        // Register a keyboard handler
        this.window.handleKeyEvent = (KeyEvent event) {

            if (oldKeyHandler) oldKeyHandler(event);

            const key = event.key.toGlui;

            // Released
            if (!event.pressed)
                _keyboardState[key] = InputState.released;

            // Repeat
            else if (isDown(key))
                _keyboardState[key] = InputState.repeated;

            // Pressed
            else
                _keyboardState[key] = InputState.pressed;

        };

        // Register character handler
        this.window.handleCharEvent = (dchar character) {

            import std.uni;

            if (oldCharHandler) oldCharHandler(character);

            // Ignore control characters
            if (character.isControl) return;

            // Send new characters
            _characterQueue ~= character;

        };

        // Register a resize handler
        this.window.windowResized = (int width, int height) {

            if (oldWindowResized) oldWindowResized(width, height);

            // Update window size
            _hasJustResized = true;
            glViewport(0, 0, width, height);

        };

        this.window.onDpiChanged = () {

            if (oldOnDpiChanged) oldOnDpiChanged();

            // Update window size
            _hasJustResized = true;
            updateDPI();

        };

    }

    bool isPressed(GluiMouseButton button) const {

        return _mouseState[button] == InputState.pressed;

    }

    bool isReleased(GluiMouseButton button) const {

        return _mouseState[button] == InputState.released;

    }

    bool isDown(GluiMouseButton button) const {

        return _mouseState[button].among(InputState.pressed, InputState.down) != 0;

    }

    bool isUp(GluiMouseButton button) const {

        return _mouseState[button].among(InputState.released, InputState.up) != 0;

    }

    bool isPressed(GluiKeyboardKey key) const {

        return _keyboardState[key] == InputState.pressed;

    }

    bool isReleased(GluiKeyboardKey key) const {

        return _keyboardState[key] == InputState.released;

    }

    bool isDown(GluiKeyboardKey key) const {

        return _keyboardState[key].among(InputState.pressed, InputState.repeated, InputState.down) != 0;

    }

    bool isUp(GluiKeyboardKey key) const {

        return _keyboardState[key].among(InputState.released, InputState.up) != 0;

    }

    bool isRepeated(GluiKeyboardKey key) const {

        return _keyboardState[key] == InputState.repeated;

    }


    dchar inputCharacter() {

        // No characters in queue
        if (_characterQueue.length == 0)
            return '\0';

        // Pop the first character
        auto result = _characterQueue[0];
        _characterQueue = _characterQueue[1..$];
        return result;

    }

    bool isPressed(int controller, GluiGamepadButton button) const
        => false;
    bool isReleased(int controller, GluiGamepadButton button) const
        => false;
    bool isDown(int controller, GluiGamepadButton button) const
        => false;
    bool isUp(int controller, GluiGamepadButton button) const
        => true;

    private void updateDPI() @trusted {

        _dpi = either(window.actualDpi, 96);

    }

    /// Update event state.
    void poll() {

        // Calculate delta time
        _deltaTime = _stopWatch.peek.total!"msecs" / 1000f;
        _stopWatch.reset();

        // Reset frame state
        _hasJustResized = false;
        _characterQueue = null;

        foreach (ref state; _keyboardState) {
            if (state == state.pressed) state = state.down;
            if (state == state.repeated) state = state.down;
            if (state == state.released) state = state.up;
        }

        foreach (ref state; _mouseState) {
            if (state == state.pressed) state = state.down;
            if (state == state.released) state = state.up;
        }

    }

    Vector2 mousePosition(Vector2 position) @trusted {

        auto positionRay = toSdpyCoords(position);
        window.warpMouse(cast(int) positionRay.x, cast(int) positionRay.y);
        return _mousePosition = position;

    }

    Vector2 mousePosition() const @trusted {

        return toGluiCoords(_mousePosition);

    }

    float deltaTime() const @trusted {

        return _deltaTime;

    }

    bool hasJustResized() const @trusted {

        return _hasJustResized;

    }

    Vector2 windowSize(Vector2 size) @trusted {

        auto sizeRay = toSdpyCoords(size);
        window.resize(cast(int) sizeRay.x, cast(int) sizeRay.y);
        return size;

    }

    Vector2 windowSize() const @trusted {

        return toGluiCoords(Vector2(window.width, window.height));

    }

    /// Convert window coordinates to OpenGL coordinates; done *after* toSdpyCoords.
    Vector2 toGL(Vector2 coords) {

        return Vector2(
            coords.x / window.width * 2 - 1,
            1 - coords.y / window.height * 2
        );

    }

    /// Create a vertex at given screenspace position
    void vertex(Vector2 coords) @trusted {

        glVertex2f(toGL(coords).tupleof);

    }

    float scale() const {

        return _scale;

    }

    float scale(float value) {

        return _scale = value;

    }

    Vector2 dpi() const @trusted {

        return Vector2(_dpi, _dpi) * scale;

    }

    Vector2 toSdpyCoords(Vector2 position) const @trusted {

        return Vector2(position.x * hidpiScale.x, position.y * hidpiScale.y);

    }

    Rectangle toSdpyCoords(Rectangle rec) const @trusted {

        return Rectangle(
            rec.x * hidpiScale.x,
            rec.y * hidpiScale.y,
            rec.width * hidpiScale.x,
            rec.height * hidpiScale.y,
        );

    }

    Vector2 toGluiCoords(Vector2 position) const @trusted {

        return Vector2(position.x / hidpiScale.x, position.y / hidpiScale.y);

    }

    Vector2 toGluiCoords(float x, float y) const @trusted {

        return Vector2(x / hidpiScale.x, y / hidpiScale.y);

    }

    Rectangle toGluiCoords(Rectangle rec) const @trusted {

        return Rectangle(
            rec.x / hidpiScale.x,
            rec.y / hidpiScale.y,
            rec.width / hidpiScale.x,
            rec.height / hidpiScale.y,
        );

    }

    Rectangle area(Rectangle rect) @trusted {

        auto rectRay = toSdpyCoords(rect);

        glEnable(GL_SCISSOR_TEST);
        glScissor(
            cast(int) rectRay.x,
            cast(int) (window.height - rectRay.y - rectRay.height),
            cast(int) rectRay.width,
            cast(int) rectRay.height,
        );
        _scissorsEnabled = true;

        return _scissors = rect;

    }

    Rectangle area() const {

        if (_scissorsEnabled)
            return _scissors;
        else
            return Rectangle(0, 0, windowSize.tupleof);

    }

    void restoreArea() @trusted {

        glDisable(GL_SCISSOR_TEST);
        _scissorsEnabled = false;

    }

    GluiMouseCursor mouseCursor(GluiMouseCursor cursor) @trusted {

        // Hide the cursor
        if (cursor.system == cursor.system.none) {
            window.hideCursor();
        }

        // Show the cursor
        else {
            window.showCursor();
            window.cursor = cursor.toSimpleDisplay;
        }

        return _cursor = cursor;

    }

    GluiMouseCursor mouseCursor() const {

        return _cursor;

    }

    Texture loadTexture(Image image) @system {

        Texture result;
        result.backend = this;
        result.width = image.width;
        result.height = image.height;

        // Create an OpenGL texture
        glGenTextures(1, &result.id);
        glBindTexture(GL_TEXTURE_2D, result.id);

        // No filtering
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

        // Repeat on
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

        // Upload the data
        glTexImage2D(

            // 2D texture, no mipmaps, four channels
            GL_TEXTURE_2D, 0, GL_RGBA,

            // Size
            image.width, image.height,

            // No border
            0,

            // Formatted as R8B8G8A8
            GL_RGBA, GL_UNSIGNED_BYTE, image.pixels.ptr,

        );

        // Unbind the texture
        glBindTexture(GL_TEXTURE_2D, 0);

        return result;

    }

    Image loadImage(string filename) @system {

        version (Have_arsd_official_image_files) {

            import arsd.image;

            // Load the image
            auto image = loadImageFromFile(filename).getAsTrueColorImage;

            // Convert to a Glui image
            Image result;
            result.pixels = cast(Color[]) image.imageData.bytes;
            result.width = image.width;
            result.height = image.height;
            return result;

        }

        else assert(false, "arsd-official:image_files is required to load images from files");

    }

    Texture loadTexture(string filename) @system {

        return loadTexture(loadImage(filename));

    }

    /// Destroy a texture
    void unloadTexture(Texture texture) @system {

        if (texture.id == 0) return;

        glDeleteTextures(1, &texture.id);

    }

    private void openglDraw() @trusted {

        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glEnable(GL_BLEND);
        glLoadIdentity();

    }

    void drawLine(Vector2 start, Vector2 end, Color color) @trusted {

        openglDraw();
        glBegin(GL_LINES);

        glColor4ub(color.tupleof);
        vertex(toSdpyCoords(start));
        vertex(toSdpyCoords(end));

        glEnd();

    }

    void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) @trusted {

        openglDraw();
        glBegin(GL_TRIANGLES);
        glColor4ub(color.tupleof);
        vertex(toSdpyCoords(a));
        vertex(toSdpyCoords(b));
        vertex(toSdpyCoords(c));
        glEnd();

    }

    void drawRectangle(Rectangle rectangle, Color color) @trusted {

        drawRectangleImpl(toSdpyCoords(rectangle), color);

    }

    private void drawRectangleImpl(Rectangle rectangle, Color color) @trusted {

        import glui.utils;

        openglDraw();
        glBegin(GL_TRIANGLES);

        glColor4ub(color.tupleof);

        //  d--c
        //  | /|
        //  |/ |
        //  a--b
        const a = start(rectangle) + Vector2(0, rectangle.height);
        const b = end(rectangle);
        const d = start(rectangle);
        const c = start(rectangle) + Vector2(rectangle.width, 0);

        // First triangle
        glTexCoord2f(0, 0);
        vertex(d);
        glColor4ub(color.tupleof);
        glTexCoord2f(0, 1);
        vertex(a);
        glColor4ub(color.tupleof);
        glTexCoord2f(1, 0);
        vertex(c);

        // Second triangle
        glColor4ub(color.tupleof);
        glTexCoord2f(1, 0);
        vertex(c);
        glColor4ub(color.tupleof);
        glTexCoord2f(0, 1);
        vertex(a);
        glColor4ub(color.tupleof);
        glTexCoord2f(1, 1);
        vertex(b);

        glEnd();

    }

    void drawTexture(Texture texture, Vector2 position, Color tint, string altText) @trusted
    in (false)
    do {

        drawTextureImpl(texture, position, tint, altText, false);

    }

    void drawTextureAlign(Texture texture, Vector2 position, Color tint, string altText) @trusted
    in (false)
    do {

        drawTextureImpl(texture, position, tint, altText, true);

    }

    @trusted
    private void drawTextureImpl(Texture texture, Vector2 position, Color tint, string altText, bool alignPixels) {

        import std.math;

        auto rectangle = Rectangle(
            toSdpyCoords(position).tupleof,
            texture.width * dpi.x / texture.dpiX,
            texture.height * dpi.y / texture.dpiY,
        );

        if (alignPixels) {
            rectangle.x = floor(rectangle.x);
            rectangle.y = floor(rectangle.y);
        }

        glEnable(GL_TEXTURE_2D);
        glBindTexture(GL_TEXTURE_2D, texture.id);
        drawRectangleImpl(rectangle, tint);
        glBindTexture(GL_TEXTURE_2D, 0);

    }

}

GluiMouseButton toGlui(arsd.simpledisplay.MouseButton button) {

     switch (button) {

        default:
        case button.none: return GluiMouseButton.none;
        case button.left: return GluiMouseButton.left;
        case button.middle: return GluiMouseButton.middle;
        case button.right: return GluiMouseButton.right;
        case button.wheelUp: return GluiMouseButton.scrollUp;
        case button.wheelDown: return GluiMouseButton.scrollDown;
        case button.backButton: return GluiMouseButton.back;
        case button.forwardButton: return GluiMouseButton.forward;

    }

}

GluiKeyboardKey toGlui(arsd.simpledisplay.Key key) {

     switch (key) {

        default: return GluiKeyboardKey.none;
        case key.Escape: return GluiKeyboardKey.escape;
        case key.Backspace: return GluiKeyboardKey.backspace;
        case key.F1: return GluiKeyboardKey.f1;
        case key.F2: return GluiKeyboardKey.f2;
        case key.F3: return GluiKeyboardKey.f3;
        case key.F4: return GluiKeyboardKey.f4;
        case key.F5: return GluiKeyboardKey.f5;
        case key.F6: return GluiKeyboardKey.f6;
        case key.F7: return GluiKeyboardKey.f7;
        case key.F8: return GluiKeyboardKey.f8;
        case key.F9: return GluiKeyboardKey.f9;
        case key.F10: return GluiKeyboardKey.f10;
        case key.F11: return GluiKeyboardKey.f11;
        case key.F12: return GluiKeyboardKey.f12;
        case key.PrintScreen: return GluiKeyboardKey.printScreen;
        case key.ScrollLock: return GluiKeyboardKey.scrollLock;
        case key.Pause: return GluiKeyboardKey.pause;
        case key.Grave: return GluiKeyboardKey.grave;
        case key.N0: return GluiKeyboardKey.digit0;
        case key.N1: return GluiKeyboardKey.digit1;
        case key.N2: return GluiKeyboardKey.digit2;
        case key.N3: return GluiKeyboardKey.digit3;
        case key.N4: return GluiKeyboardKey.digit4;
        case key.N5: return GluiKeyboardKey.digit5;
        case key.N6: return GluiKeyboardKey.digit6;
        case key.N7: return GluiKeyboardKey.digit7;
        case key.N8: return GluiKeyboardKey.digit8;
        case key.N9: return GluiKeyboardKey.digit9;
        case key.Dash: return GluiKeyboardKey.dash;
        case key.Equals: return GluiKeyboardKey.equal;
        case key.Backslash: return GluiKeyboardKey.backslash;
        case key.Insert: return GluiKeyboardKey.insert;
        case key.Home: return GluiKeyboardKey.home;
        case key.PageUp: return GluiKeyboardKey.pageUp;
        case key.PageDown: return GluiKeyboardKey.pageDown;
        case key.Delete: return GluiKeyboardKey.del;
        case key.End: return GluiKeyboardKey.end;
        case key.Up: return GluiKeyboardKey.up;
        case key.Down: return GluiKeyboardKey.down;
        case key.Left: return GluiKeyboardKey.left;
        case key.Right: return GluiKeyboardKey.right;
        case key.Tab: return GluiKeyboardKey.tab;
        case key.Q: return GluiKeyboardKey.q;
        case key.W: return GluiKeyboardKey.w;
        case key.E: return GluiKeyboardKey.e;
        case key.R: return GluiKeyboardKey.r;
        case key.T: return GluiKeyboardKey.t;
        case key.Y: return GluiKeyboardKey.y;
        case key.U: return GluiKeyboardKey.u;
        case key.I: return GluiKeyboardKey.i;
        case key.O: return GluiKeyboardKey.o;
        case key.P: return GluiKeyboardKey.p;
        case key.LeftBracket: return GluiKeyboardKey.leftBracket;
        case key.RightBracket: return GluiKeyboardKey.rightBracket;
        case key.CapsLock: return GluiKeyboardKey.capsLock;
        case key.A: return GluiKeyboardKey.a;
        case key.S: return GluiKeyboardKey.s;
        case key.D: return GluiKeyboardKey.d;
        case key.F: return GluiKeyboardKey.f;
        case key.G: return GluiKeyboardKey.g;
        case key.H: return GluiKeyboardKey.h;
        case key.J: return GluiKeyboardKey.j;
        case key.K: return GluiKeyboardKey.k;
        case key.L: return GluiKeyboardKey.l;
        case key.Semicolon: return GluiKeyboardKey.semicolon;
        case key.Apostrophe: return GluiKeyboardKey.apostrophe;
        case key.Enter: return GluiKeyboardKey.enter;
        case key.Shift: return GluiKeyboardKey.leftShift;
        case key.Z: return GluiKeyboardKey.z;
        case key.X: return GluiKeyboardKey.x;
        case key.C: return GluiKeyboardKey.c;
        case key.V: return GluiKeyboardKey.v;
        case key.B: return GluiKeyboardKey.b;
        case key.N: return GluiKeyboardKey.n;
        case key.M: return GluiKeyboardKey.m;
        case key.Comma: return GluiKeyboardKey.comma;
        case key.Period: return GluiKeyboardKey.period;
        case key.Slash: return GluiKeyboardKey.slash;
        case key.Shift_r: return GluiKeyboardKey.rightShift;
        case key.Ctrl: return GluiKeyboardKey.leftControl;
        case key.Windows: return GluiKeyboardKey.leftSuper;
        case key.Alt: return GluiKeyboardKey.leftAlt;
        case key.Space: return GluiKeyboardKey.space;
        case key.Alt_r: return GluiKeyboardKey.rightAlt;
        case key.Windows_r: return GluiKeyboardKey.rightSuper;
        case key.Menu: return GluiKeyboardKey.contextMenu;
        case key.Ctrl_r: return GluiKeyboardKey.rightControl;
        case key.NumLock: return GluiKeyboardKey.numLock;
        case key.Divide: return GluiKeyboardKey.keypadDivide;
        case key.Multiply: return GluiKeyboardKey.keypadMultiply;
        case key.Minus: return GluiKeyboardKey.keypadSubtract;
        case key.Plus: return GluiKeyboardKey.keypadSum;
        case key.PadEnter: return GluiKeyboardKey.keypadEnter;
        case key.Pad0: return GluiKeyboardKey.keypad0;
        case key.Pad1: return GluiKeyboardKey.keypad1;
        case key.Pad2: return GluiKeyboardKey.keypad2;
        case key.Pad3: return GluiKeyboardKey.keypad3;
        case key.Pad4: return GluiKeyboardKey.keypad4;
        case key.Pad5: return GluiKeyboardKey.keypad5;
        case key.Pad6: return GluiKeyboardKey.keypad6;
        case key.Pad7: return GluiKeyboardKey.keypad7;
        case key.Pad8: return GluiKeyboardKey.keypad8;
        case key.Pad9: return GluiKeyboardKey.keypad9;
        case key.PadDot: return GluiKeyboardKey.keypadDecimal;

    }

}

MouseCursor toSimpleDisplay(GluiMouseCursor cursor) @trusted {

    switch (cursor.system) {

        default:
        case cursor.system.systemDefault:
        case cursor.system.none:
            return GenericCursor.Default;

        case cursor.system.pointer: return GenericCursor.Hand;
        case cursor.system.crosshair: return GenericCursor.Cross;
        case cursor.system.text: return GenericCursor.Text;
        case cursor.system.allScroll: return GenericCursor.Move;
        case cursor.system.resizeEW: return GenericCursor.SizeWe;
        case cursor.system.resizeNS: return GenericCursor.SizeNs;
        case cursor.system.resizeNESW: return GenericCursor.SizeNesw;
        case cursor.system.resizeNWSE: return GenericCursor.SizeNwse;
        case cursor.system.notAllowed: return GenericCursor.NotAllowed;

    }

}
