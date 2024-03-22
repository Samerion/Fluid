module fluid.backend.simpledisplay;

version (Have_arsd_official_simpledisplay):

debug (Fluid_BuildMessages) {
    pragma(msg, "Fluid: Building with arsd.simpledisplay support");
}

import arsd.simpledisplay;

import std.algorithm;
import std.datetime.stopwatch;

import fluid.backend;


@safe:


private {
    alias Rectangle = fluid.backend.Rectangle;
    alias Color = fluid.backend.Color;
    alias Image = fluid.backend.Image;
    alias MouseButton = fluid.backend.MouseButton;
}

class SimpledisplayBackend : FluidBackend {

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
        FluidMouseCursor _cursor;
        Color _tint = color!"fff";

        TextureReaper _reaper;

        /// Recent input events for keyboard and mouse.
        InputState[KeyboardKey.max+1] _keyboardState;
        InputState[MouseButton.max+1] _mouseState;
        int _scroll;
        // gamepads?

        /// Characters typed by the user, awaiting consumption.
        const(dchar)[] _characterQueue;

        // Missing from simpledisplay at the time of writing
        extern(C) void function(GLint x, GLint y, GLsizei width, GLsizei height) glScissor;

    }

    // TODO non-openGL backend, maybe...

    /// Initialize the backend using the given window.
    ///
    /// Make sure to call `SimpledisplayBackend.poll()` *after* the Fluid `draw` call, and only do it once per frame,
    /// other Fluid might not be able to keep itself up to date with latest events.
    ///
    /// Please note Fluid will register its own event handlers, so if you
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

            // Scroll event
            if (const scroll = event.button.scrollValue) {

                if (event.type == event.type.buttonPressed) {

                    _scroll = scroll;

                }

            }

            // Other events
            else final switch (event.type) {

                // Update mouse position
                case event.type.motion:
                    _mousePosition = Vector2(event.x, event.y);
                    return;

                // Update button state
                case event.type.buttonPressed:
                    _mouseState[event.button.toFluid] = InputState.pressed;
                    return;

                case event.type.buttonReleased:
                    _mouseState[event.button.toFluid] = InputState.released;
                    return;

            }

        };

        // Register a keyboard handler
        this.window.handleKeyEvent = (KeyEvent event) {

            if (oldKeyHandler) oldKeyHandler(event);

            const key = event.key.toFluid;

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

    bool isPressed(MouseButton button) const {

        return _mouseState[button] == InputState.pressed;

    }

    bool isReleased(MouseButton button) const {

        return _mouseState[button] == InputState.released;

    }

    bool isDown(MouseButton button) const {

        return _mouseState[button].among(InputState.pressed, InputState.down) != 0;

    }

    bool isUp(MouseButton button) const {

        return _mouseState[button].among(InputState.released, InputState.up) != 0;

    }

    bool isPressed(KeyboardKey key) const {

        return _keyboardState[key] == InputState.pressed;

    }

    bool isReleased(KeyboardKey key) const {

        return _keyboardState[key] == InputState.released;

    }

    bool isDown(KeyboardKey key) const {

        return _keyboardState[key].among(InputState.pressed, InputState.repeated, InputState.down) != 0;

    }

    bool isUp(KeyboardKey key) const {

        return _keyboardState[key].among(InputState.released, InputState.up) != 0;

    }

    bool isRepeated(KeyboardKey key) const {

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

    int isPressed(GamepadButton button) const
        => 0;
    int isReleased(GamepadButton button) const
        => 0;
    int isDown(GamepadButton button) const
        => 0;
    int isUp(GamepadButton button) const
        => 1;
    int isRepeated(GamepadButton button) const
        => 0;

    private void updateDPI() @trusted {

        _dpi = either(window.actualDpi, 96);

    }

    /// Update event state. To be called *after* drawing.
    void poll() {

        // Calculate delta time
        _deltaTime = _stopWatch.peek.total!"msecs" / 1000f;
        _stopWatch.reset();

        // Reset frame state
        _hasJustResized = false;
        _characterQueue = null;
        _scroll = 0;

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

    Vector2 mousePosition() const {

        return toFluidCoords(_mousePosition);

    }

    Vector2 scroll() const {

        return Vector2(0, _scroll);

    }

    string clipboard(string value) @trusted {

        window.setClipboardText(value);
        return value;

    }

    string clipboard() const @trusted {

        // TODO
        return null;

    }

    float deltaTime() const {

        return _deltaTime;

    }

    bool hasJustResized() const {

        return _hasJustResized;

    }

    Vector2 windowSize(Vector2 size) @trusted {

        auto sizeRay = toSdpyCoords(size);
        window.resize(cast(int) sizeRay.x, cast(int) sizeRay.y);
        return size;

    }

    Vector2 windowSize() const {

        return toFluidCoords(Vector2(window.width, window.height));

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

    Vector2 toFluidCoords(Vector2 position) const @trusted {

        return Vector2(position.x / hidpiScale.x, position.y / hidpiScale.y);

    }

    Vector2 toFluidCoords(float x, float y) const @trusted {

        return Vector2(x / hidpiScale.x, y / hidpiScale.y);

    }

    Rectangle toFluidCoords(Rectangle rec) const @trusted {

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

    FluidMouseCursor mouseCursor(FluidMouseCursor cursor) @trusted {

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

    FluidMouseCursor mouseCursor() const {

        return _cursor;

    }

    TextureReaper* reaper() return scope {

        return &_reaper;

    }

    Texture loadTexture(Image image) @system {

        Texture result;
        result.width = image.width;
        result.height = image.height;

        // Create an OpenGL texture
        glGenTextures(1, &result.id);
        glBindTexture(GL_TEXTURE_2D, result.id);

        // Prepare the tombstone
        result.tombstone = reaper.makeTombstone(this, result.id);

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

    void updateTexture(Texture texture, Image image) @system
    in (false)
    do {

        // Use the texture
        glBindTexture(GL_TEXTURE_2D, texture.id);
        scope (exit) glBindTexture(GL_TEXTURE_2D, 0);

        const offsetX = 0;
        const offsetY = 0;
        const format = GL_RGBA;
        const type = GL_UNSIGNED_BYTE;

        // Update the content
        glTexSubImage2D(GL_TEXTURE_2D, 0, offsetX, offsetY, texture.width, texture.height, format, type,
            image.pixels.ptr);

    }

    Image loadImage(string filename) @system {

        version (Have_arsd_official_image_files) {

            import arsd.image;

            // Load the image
            auto image = loadImageFromFile(filename).getAsTrueColorImage;

            // Convert to a Fluid image
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
    void unloadTexture(uint id) @system {

        if (id == 0) return;

        glDeleteTextures(1, &id);

    }

    private void openglDraw() @trusted {

        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glEnable(GL_BLEND);
        glLoadIdentity();

        // This must be present, otherwise the AMD Linux driver will hang when the window is resized. I don't have the
        // slightest clue why.
        if (auto error = glGetError()) {
            import std.stdio;
            debug writeln(error);
        }

    }

    Color tint(Color color) {

        return _tint = color;

    }

    Color tint() const {

        return _tint;

    }

    void drawLine(Vector2 start, Vector2 end, Color color) @trusted {

        color = multiply(color, tint);

        openglDraw();
        glBegin(GL_LINES);

        glColor4ub(color.tupleof);
        vertex(toSdpyCoords(start));
        vertex(toSdpyCoords(end));

        glEnd();

    }

    void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) @trusted {

        color = multiply(color, tint);

        openglDraw();
        glBegin(GL_TRIANGLES);
        glColor4ub(color.tupleof);
        vertex(toSdpyCoords(a));
        vertex(toSdpyCoords(b));
        vertex(toSdpyCoords(c));
        glEnd();

    }

    void drawCircle(Vector2 center, float radius, Color color) @trusted {

        import std.math;

        if (radius == 0) return;

        center = toSdpyCoords(center);
        color = multiply(color, tint);

        openglDraw();
        glBegin(GL_QUADS);

        const stepCount = 18;
        const step = PI / stepCount;

        foreach (i; 0..stepCount) {

            const angle = 2 * step * i;

            glColor4ub(color.tupleof);
            vertex(center);
            vertex(center + radius * Vector2(
                cos(angle + step*2) * hidpiScale.x,
                sin(angle + step*2) * hidpiScale.y));
            vertex(center + radius * Vector2(
                cos(angle + step) * hidpiScale.x,
                sin(angle + step) * hidpiScale.y));
            vertex(center + radius * Vector2(
                cos(angle) * hidpiScale.x,
                sin(angle) * hidpiScale.y));

        }

        glEnd();

    }

    void drawCircleOutline(Vector2 center, float radius, Color color) @trusted {

        import std.math;

        if (radius == 0) return;

        center = toSdpyCoords(center);
        color = multiply(color, tint);

        openglDraw();
        glBegin(GL_LINES);

        const stepCount = 36;
        const step = 2 * PI / stepCount;

        foreach (i; 0..stepCount) {

            const angle = i * step;

            glColor4ub(color.tupleof);
            vertex(center + radius * Vector2(
                cos(angle) * hidpiScale.x,
                sin(angle) * hidpiScale.y));
            vertex(center + radius * Vector2(
                cos(angle + step) * hidpiScale.x,
                sin(angle + step) * hidpiScale.y));

        }

        glEnd();

    }

    void drawRectangle(Rectangle rectangle, Color color) @trusted {

        drawRectangleImpl(toSdpyCoords(rectangle), color);

    }

    private void drawRectangleImpl(Rectangle rectangle, Color color) @trusted {

        color = multiply(color, tint);

        import fluid.utils;

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
        glTexCoord2f(0, 1);
        vertex(a);
        glTexCoord2f(1, 0);
        vertex(c);

        // Second triangle
        glTexCoord2f(1, 0);
        vertex(c);
        glTexCoord2f(0, 1);
        vertex(a);
        glTexCoord2f(1, 1);
        vertex(b);

        glEnd();

    }

    void drawTexture(Texture texture, Rectangle rectangle, Color tint) @trusted
    in (false)
    do {

        // TODO filtering?
        drawTextureImpl(texture, rectangle, tint, false);

    }

    void drawTextureAlign(Texture texture, Rectangle rectangle, Color tint) @trusted
    in (false)
    do {

        drawTextureImpl(texture, rectangle, tint, true);

    }

    @trusted
    private void drawTextureImpl(Texture texture, Rectangle rectangle, Color tint, bool alignPixels)
    do {

        import std.math;

        rectangle = toSdpyCoords(rectangle);

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

int scrollValue(arsd.simpledisplay.MouseButton button) {

    switch (button) {

        case button.wheelUp: return -1;
        case button.wheelDown: return +1;
        default: return 0;

    }

}

MouseButton toFluid(arsd.simpledisplay.MouseButton button) {

     switch (button) {

        default:
        case button.wheelUp:
        case button.wheelDown:
        case button.none: return MouseButton.none;
        case button.left: return MouseButton.left;
        case button.middle: return MouseButton.middle;
        case button.right: return MouseButton.right;
        case button.backButton: return MouseButton.back;
        case button.forwardButton: return MouseButton.forward;

    }

}

KeyboardKey toFluid(arsd.simpledisplay.Key key) {

     switch (key) {

        default: return KeyboardKey.none;
        case key.Escape: return KeyboardKey.escape;
        case key.Backspace: return KeyboardKey.backspace;
        case key.F1: return KeyboardKey.f1;
        case key.F2: return KeyboardKey.f2;
        case key.F3: return KeyboardKey.f3;
        case key.F4: return KeyboardKey.f4;
        case key.F5: return KeyboardKey.f5;
        case key.F6: return KeyboardKey.f6;
        case key.F7: return KeyboardKey.f7;
        case key.F8: return KeyboardKey.f8;
        case key.F9: return KeyboardKey.f9;
        case key.F10: return KeyboardKey.f10;
        case key.F11: return KeyboardKey.f11;
        case key.F12: return KeyboardKey.f12;
        case key.PrintScreen: return KeyboardKey.printScreen;
        case key.ScrollLock: return KeyboardKey.scrollLock;
        case key.Pause: return KeyboardKey.pause;
        case key.Grave: return KeyboardKey.grave;
        case key.N0: return KeyboardKey.digit0;
        case key.N1: return KeyboardKey.digit1;
        case key.N2: return KeyboardKey.digit2;
        case key.N3: return KeyboardKey.digit3;
        case key.N4: return KeyboardKey.digit4;
        case key.N5: return KeyboardKey.digit5;
        case key.N6: return KeyboardKey.digit6;
        case key.N7: return KeyboardKey.digit7;
        case key.N8: return KeyboardKey.digit8;
        case key.N9: return KeyboardKey.digit9;
        case key.Dash: return KeyboardKey.dash;
        case key.Equals: return KeyboardKey.equal;
        case key.Backslash: return KeyboardKey.backslash;
        case key.Insert: return KeyboardKey.insert;
        case key.Home: return KeyboardKey.home;
        case key.PageUp: return KeyboardKey.pageUp;
        case key.PageDown: return KeyboardKey.pageDown;
        case key.Delete: return KeyboardKey.del;
        case key.End: return KeyboardKey.end;
        case key.Up: return KeyboardKey.up;
        case key.Down: return KeyboardKey.down;
        case key.Left: return KeyboardKey.left;
        case key.Right: return KeyboardKey.right;
        case key.Tab: return KeyboardKey.tab;
        case key.Q: return KeyboardKey.q;
        case key.W: return KeyboardKey.w;
        case key.E: return KeyboardKey.e;
        case key.R: return KeyboardKey.r;
        case key.T: return KeyboardKey.t;
        case key.Y: return KeyboardKey.y;
        case key.U: return KeyboardKey.u;
        case key.I: return KeyboardKey.i;
        case key.O: return KeyboardKey.o;
        case key.P: return KeyboardKey.p;
        case key.LeftBracket: return KeyboardKey.leftBracket;
        case key.RightBracket: return KeyboardKey.rightBracket;
        case key.CapsLock: return KeyboardKey.capsLock;
        case key.A: return KeyboardKey.a;
        case key.S: return KeyboardKey.s;
        case key.D: return KeyboardKey.d;
        case key.F: return KeyboardKey.f;
        case key.G: return KeyboardKey.g;
        case key.H: return KeyboardKey.h;
        case key.J: return KeyboardKey.j;
        case key.K: return KeyboardKey.k;
        case key.L: return KeyboardKey.l;
        case key.Semicolon: return KeyboardKey.semicolon;
        case key.Apostrophe: return KeyboardKey.apostrophe;
        case key.Enter: return KeyboardKey.enter;
        case key.Shift: return KeyboardKey.leftShift;
        case key.Z: return KeyboardKey.z;
        case key.X: return KeyboardKey.x;
        case key.C: return KeyboardKey.c;
        case key.V: return KeyboardKey.v;
        case key.B: return KeyboardKey.b;
        case key.N: return KeyboardKey.n;
        case key.M: return KeyboardKey.m;
        case key.Comma: return KeyboardKey.comma;
        case key.Period: return KeyboardKey.period;
        case key.Slash: return KeyboardKey.slash;
        case key.Shift_r: return KeyboardKey.rightShift;
        case key.Ctrl: return KeyboardKey.leftControl;
        case key.Windows: return KeyboardKey.leftSuper;
        case key.Alt: return KeyboardKey.leftAlt;
        case key.Space: return KeyboardKey.space;
        case key.Alt_r: return KeyboardKey.rightAlt;
        case key.Windows_r: return KeyboardKey.rightSuper;
        case key.Menu: return KeyboardKey.contextMenu;
        case key.Ctrl_r: return KeyboardKey.rightControl;
        case key.NumLock: return KeyboardKey.numLock;
        case key.Divide: return KeyboardKey.keypadDivide;
        case key.Multiply: return KeyboardKey.keypadMultiply;
        case key.Minus: return KeyboardKey.keypadSubtract;
        case key.Plus: return KeyboardKey.keypadSum;
        case key.PadEnter: return KeyboardKey.keypadEnter;
        case key.Pad0: return KeyboardKey.keypad0;
        case key.Pad1: return KeyboardKey.keypad1;
        case key.Pad2: return KeyboardKey.keypad2;
        case key.Pad3: return KeyboardKey.keypad3;
        case key.Pad4: return KeyboardKey.keypad4;
        case key.Pad5: return KeyboardKey.keypad5;
        case key.Pad6: return KeyboardKey.keypad6;
        case key.Pad7: return KeyboardKey.keypad7;
        case key.Pad8: return KeyboardKey.keypad8;
        case key.Pad9: return KeyboardKey.keypad9;
        case key.PadDot: return KeyboardKey.keypadDecimal;

    }

}

MouseCursor toSimpleDisplay(FluidMouseCursor cursor) @trusted {

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
