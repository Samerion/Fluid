/// This module handles input/output facilities Fluid requires to operate. It connects backends like Raylib, exposing
/// them under a common interface so they can be changed at will.
///
/// Fluid comes with a built-in interface for Raylib.
module fluid.backend;

import std.meta;
import std.range;
import std.traits;
import std.datetime;
import std.algorithm;

public import raylib.raylib_types;
public import fluid.backend.raylib5;
public import fluid.backend.headless;
public import fluid.graphics;  // legacy/compatibility

version (Have_raylib_d) {
    public static import raylib;
    public import raylib : Color;
}


@safe:

alias VoidDelegate = void delegate() @safe;

pragma(mangle, "fluid_defaultBackend")
FluidBackend defaultFluidBackend();

/// `FluidBackend` is an interface making it possible to bind Fluid to a library other than Raylib.
///
/// The default unit in graphical space is a **pixel** (`px`), here defined as **1/96 of an inch**. This is unless
/// stated otherwise, as in `Texture`.
///
/// Warning: Backend API is unstable and functions may be added or removed with no prior warning.
interface FluidBackend {

    /// Get system's double click time.
    Duration doubleClickTime()() const {

        // TODO This should be overridable

        return 500.msecs;

    }

    /// Check if the given mouse button has just been pressed/released or, if it's held down or not (up).
    bool isPressed(MouseButton) const;
    bool isReleased(MouseButton) const;
    bool isDown(MouseButton) const;
    bool isUp(MouseButton) const;

    /// Check if the given keyboard key has just been pressed/released or, if it's held down or not (up).
    bool isPressed(KeyboardKey) const;
    bool isReleased(KeyboardKey) const;
    bool isDown(KeyboardKey) const;
    bool isUp(KeyboardKey) const;

    /// If true, the given keyboard key has been virtually pressed again, through a long-press.
    bool isRepeated(KeyboardKey) const;

    /// Get next queued character from user's input. The queue should be cleared every frame. Return null if no
    /// character was pressed.
    dchar inputCharacter();

    /// Check if the given gamepad button has been pressed/released or, if it's held down or not (up) on any of the
    /// connected gamepads.
    ///
    /// Returns: 0 if the event isn't taking place on any controller, or number of the controller.
    int isPressed(GamepadButton button) const;
    int isReleased(GamepadButton button) const;
    int isDown(GamepadButton button) const;
    int isUp(GamepadButton button) const;

    /// If true, the given gamepad button has been virtually pressed again, through a long-press.
    ///
    /// Returns: 0 if no controller had a button repeat this frame, or number of the controller.
    int isRepeated(GamepadButton button) const;

    /// Get/set mouse position
    Vector2 mousePosition(Vector2);
    Vector2 mousePosition() const;

    /// Get scroll value on both axes.
    Vector2 scroll() const;

    /// Get or set system clipboard value.
    string clipboard(string);
    string clipboard() const;

    /// Get time elapsed since last frame in seconds.
    float deltaTime() const;

    /// True if the user has just resized the window.
    bool hasJustResized() const;

    /// Get or set the size of the window.
    Vector2 windowSize(Vector2);
    Vector2 windowSize() const;  /// ditto

    /// Set scale to apply to whatever is drawn next.
    ///
    /// Suggested implementation is to increase return value of `dpi`.
    float scale() const;

    /// ditto
    float scale(float);

    /// Get horizontal and vertical DPI of the window.
    Vector2 dpi() const;

    /// Get the DPI value for the window as a scale relative to 96 DPI.
    Vector2 hidpiScale()() const {

        const dpi = this.dpi;
        return Vector2(dpi.x / 96f, dpi.y / 96f);

    }

    /// Set area within the window items will be drawn to; any pixel drawn outside will be discarded.
    Rectangle area(Rectangle rect);
    Rectangle area() const;

    /// Restore the capability to draw anywhere in the window.
    void restoreArea();

    /// Get or set mouse cursor icon.
    FluidMouseCursor mouseCursor(FluidMouseCursor);
    FluidMouseCursor mouseCursor() const;

    /// Texture reaper used by this backend. May be null.
    ///
    /// Highly recommended for OpenGL-based backends.
    TextureReaper* reaper() return scope;

    /// Load a texture from memory or file.
    Texture loadTexture(Image image) @system;
    Texture loadTexture(string filename) @system;

    /// Update a texture from an image. The texture must be valid and must be of the same size and format as the image.
    void updateTexture(Texture texture, Image image) @system
    in (texture.format == image.format)
    in (texture.width == image.width)
    in (texture.height == image.height);

    /// Destroy a texture created by this backend. Always use `texture.destroy()` to ensure thread safety and invoking
    /// the correct backend.
    void unloadTexture(uint id) @system;

    /// ditto
    void unloadTexture()(Texture texture) @system {

        unloadTexture(texture.id);

    }

    /// Set tint for all newly drawn shapes. The input color for every shape should be multiplied by this color.
    Color tint(Color);

    /// Get current tint color.
    Color tint() const;

    /// Draw a line.
    void drawLine(Vector2 start, Vector2 end, Color color);

    /// Draw a triangle, consisting of 3 vertices with counter-clockwise winding.
    void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color);

    /// Draw a circle.
    void drawCircle(Vector2 center, float radius, Color color);

    /// Draw a circle, but outline only.
    void drawCircleOutline(Vector2 center, float radius, Color color);

    /// Draw a rectangle.
    void drawRectangle(Rectangle rectangle, Color color);

    /// Draw a texture.
    void drawTexture(Texture texture, Rectangle rectangle, Color tint)
    in (texture.backend is this, "Given texture comes from a different backend");

    /// Draw a texture, but ensure it aligns with pixel boundaries, recommended for text.
    void drawTextureAlign(Texture texture, Rectangle rectangle, Color tint)
    in (texture.backend is this, "Given texture comes from a different backend");

}

struct FluidMouseCursor {

    enum SystemCursors {

        systemDefault,     // Default system cursor.
        none,              // No pointer.
        pointer,           // Pointer indicating a link or button, typically a pointing hand. 👆
        crosshair,         // Cross cursor, often indicating selection inside images.
        text,              // Vertical beam indicating selectable text.
        allScroll,         // Omnidirectional scroll, content can be scrolled in any direction (panned).
        resizeEW,          // Cursor indicating the content underneath can be resized horizontally.
        resizeNS,          // Cursor indicating the content underneath can be resized vertically.
        resizeNESW,        // Diagonal resize cursor, top-right + bottom-left.
        resizeNWSE,        // Diagonal resize cursor, top-left + bottom-right.
        notAllowed,        // Indicates a forbidden action.

    }

    enum {

        systemDefault = FluidMouseCursor(SystemCursors.systemDefault),
        none          = FluidMouseCursor(SystemCursors.none),
        pointer       = FluidMouseCursor(SystemCursors.pointer),
        crosshair     = FluidMouseCursor(SystemCursors.crosshair),
        text          = FluidMouseCursor(SystemCursors.text),
        allScroll     = FluidMouseCursor(SystemCursors.allScroll),
        resizeEW      = FluidMouseCursor(SystemCursors.resizeEW),
        resizeNS      = FluidMouseCursor(SystemCursors.resizeNS),
        resizeNESW    = FluidMouseCursor(SystemCursors.resizeNESW),
        resizeNWSE    = FluidMouseCursor(SystemCursors.resizeNWSE),
        notAllowed    = FluidMouseCursor(SystemCursors.notAllowed),

    }

    /// Use a system-provided cursor.
    SystemCursors system;
    // TODO user-provided cursor image

}

enum MouseButton {
    none,
    left,         // Left (primary) mouse button.
    right,        // Right (secondary) mouse button.
    middle,       // Middle mouse button.
    extra1,       // Additional mouse button.
    extra2,       // ditto.
    forward,      // Mouse button going forward in browser history.
    back,         // Mouse button going back in browser history.

    primary = left,
    secondary = right,

}

enum GamepadButton {

    none,                // No such button
    dpadUp,              // Dpad up button.
    dpadRight,           // Dpad right button
    dpadDown,            // Dpad down button
    dpadLeft,            // Dpad left button
    triangle,            // Triangle (PS) or Y (Xbox)
    circle,              // Circle (PS) or B (Xbox)
    cross,               // Cross (PS) or A (Xbox)
    square,              // Square (PS) or X (Xbox)
    leftButton,          // Left button behind the controlller (LB).
    leftTrigger,         // Left trigger (LT).
    rightButton,         // Right button behind the controller (RB).
    rightTrigger,        // Right trigger (RT)
    select,              // "Select" button.
    vendor,              // Button with the vendor logo.
    start,               // "Start" button.
    leftStick,           // Left joystick press.
    rightStick,          // Right joystick press.

    y = triangle,
    x = square,
    a = cross,
    b = circle,

}

enum GamepadAxis {

    leftX,         // Left joystick, X axis.
    leftY,         // Left joystick, Y axis.
    rightX,        // Right joystick, X axis.
    rightY,        // Right joystick, Y axis.
    leftTrigger,   // Analog input for the left trigger.
    rightTrigger,  // Analog input for the right trigger.

}

enum KeyboardKey {
    none               = 0,           // No key pressed
    apostrophe         = 39,          // '
    comma              = 44,          // ,
    dash               = comma,
    minus              = 45,          // -
    period             = 46,          // .
    slash              = 47,          // /
    digit0             = 48,          // 0
    digit1             = 49,          // 1
    digit2             = 50,          // 2
    digit3             = 51,          // 3
    digit4             = 52,          // 4
    digit5             = 53,          // 5
    digit6             = 54,          // 6
    digit7             = 55,          // 7
    digit8             = 56,          // 8
    digit9             = 57,          // 9
    semicolon          = 59,          // ;
    equal              = 61,          // =
    a                  = 65,          // A | a
    b                  = 66,          // B | b
    c                  = 67,          // C | c
    d                  = 68,          // D | d
    e                  = 69,          // E | e
    f                  = 70,          // F | f
    g                  = 71,          // G | g
    h                  = 72,          // H | h
    i                  = 73,          // I | i
    j                  = 74,          // J | j
    k                  = 75,          // K | k
    l                  = 76,          // L | l
    m                  = 77,          // M | m
    n                  = 78,          // N | n
    o                  = 79,          // O | o
    p                  = 80,          // P | p
    q                  = 81,          // Q | q
    r                  = 82,          // R | r
    s                  = 83,          // S | s
    t                  = 84,          // T | t
    u                  = 85,          // U | u
    v                  = 86,          // V | v
    w                  = 87,          // W | w
    x                  = 88,          // X | x
    y                  = 89,          // Y | y
    z                  = 90,          // Z | z
    leftBracket        = 91,          // [
    backslash          = 92,          // '\'
    rightBracket       = 93,          // ]
    backtick           = 96,          // `
    grave              = backtick,
    space              = 32,          // Space
    escape             = 256,         // Esc
    esc                = escape,
    enter              = 257,         // Enter
    tab                = 258,         // Tab
    backspace          = 259,         // Backspace
    insert             = 260,         // Ins
    del                = 261,         // Del
    delete_            = del,
    right              = 262,         // Cursor right
    left               = 263,         // Cursor left
    down               = 264,         // Cursor down
    up                 = 265,         // Cursor up
    pageUp             = 266,         // Page up
    pageDown           = 267,         // Page down
    home               = 268,         // Home
    end                = 269,         // End
    capsLock           = 280,         // Caps lock
    scrollLock         = 281,         // Scroll down
    numLock            = 282,         // Num lock
    printScreen        = 283,         // Print screen
    pause              = 284,         // Pause
    f1                 = 290,         // F1
    f2                 = 291,         // F2
    f3                 = 292,         // F3
    f4                 = 293,         // F4
    f5                 = 294,         // F5
    f6                 = 295,         // F6
    f7                 = 296,         // F7
    f8                 = 297,         // F8
    f9                 = 298,         // F9
    f10                = 299,         // F10
    f11                = 300,         // F11
    f12                = 301,         // F12
    leftShift          = 340,         // Shift left
    leftControl        = 341,         // Control left
    leftAlt            = 342,         // Alt left
    leftSuper          = 343,         // Super left
    leftCommand        = leftSuper,   // Command left
    leftOption         = leftAlt,     // Option left
    rightShift         = 344,         // Shift right
    rightControl       = 345,         // Control right
    rightAlt           = 346,         // Alt right
    rightSuper         = 347,         // Super right
    rightCommand       = rightSuper,  // Command right
    rightOption        = rightAlt,    // Option right
    contextMenu        = 348,         // Context menu
    keypad0            = 320,         // Keypad 0
    keypad1            = 321,         // Keypad 1
    keypad2            = 322,         // Keypad 2
    keypad3            = 323,         // Keypad 3
    keypad4            = 324,         // Keypad 4
    keypad5            = 325,         // Keypad 5
    keypad6            = 326,         // Keypad 6
    keypad7            = 327,         // Keypad 7
    keypad8            = 328,         // Keypad 8
    keypad9            = 329,         // Keypad 9
    keypadDecimal      = 330,         // Keypad .
    keypadDivide       = 331,         // Keypad /
    keypadMultiply     = 332,         // Keypad *
    keypadSubtract     = 333,         // Keypad -
    keypadSum          = 334,         // Keypad +
    keypadEnter        = 335,         // Keypad Enter
    keypadEqual        = 336,         // Keypad =
    androidBack        = 4,           // Android back button
    androidMenu        = 82,          // Android menu button
    volumeUp           = 24,          // Android volume up button
    volumeDown         = 25           // Android volume down button
    // Function keys for volume?

}

version (Fluid_DefaultHeadless) {

    debug (Fluid_BuildMessages) {
        pragma(msg, "Fluid: Using headless as the default backend (unittest)");
    }

    pragma(mangle, "fluid_defaultBackend")
    FluidBackend defaultFluidBackend() {

        return new HeadlessBackend;

    }

}

else version (Fluid_DefaultRaylib) {

    debug (Fluid_BuildMessages) {
        pragma(msg, "Fluid: Using Raylib 5 as the default backend");
    }

    pragma(mangle, "fluid_defaultBackend")
    FluidBackend defaultFluidBackend() {

        return new Raylib5Backend;

    }

}
