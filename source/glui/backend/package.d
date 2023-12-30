/// This module handles input/output facilities Glui requires to operate. It connects backends like Raylib, exposing
/// them under a common interface so they can be changed at will.
///
/// Glui comes with a built-in interface for Raylib.
module glui.backend;

import std.meta;
import std.range;
import std.traits;
import std.algorithm;

public import glui.backend.raylib5;
public import glui.backend.headless;
public import glui.backend.simpledisplay;


@safe:


alias VoidDelegate = void delegate() @safe;

static GluiBackend defaultGluiBackend;

interface GluiBackend {

    /// Check if the given mouse button has just been pressed/released or, if it's held down or not (up).
    bool isPressed(GluiMouseButton) const;
    bool isReleased(GluiMouseButton) const;
    bool isDown(GluiMouseButton) const;
    bool isUp(GluiMouseButton) const;

    /// Check if the given keyboard key has just been pressed/released or, if it's held down or not (up).
    bool isPressed(GluiKeyboardKey) const;
    bool isReleased(GluiKeyboardKey) const;
    bool isDown(GluiKeyboardKey) const;
    bool isUp(GluiKeyboardKey) const;

    /// If true, the given keyboard key has been virtually pressed again, through a long-press.
    bool isRepeated(GluiKeyboardKey) const;

    /// Get next queued character from user's input. The queue should be cleared every frame. Return null if no
    /// character was pressed.
    dchar inputCharacter();

    /// Check if the given gamepad button has been pressed/released or, if it's held down or not (up).
    ///
    /// Controllers start at 0.
    bool isPressed(int controller, GluiGamepadButton button) const;
    bool isReleased(int controller, GluiGamepadButton button) const;
    bool isDown(int controller, GluiGamepadButton button) const;
    bool isUp(int controller, GluiGamepadButton button) const;

    /// Get/set mouse position
    Vector2 mousePosition(Vector2);
    Vector2 mousePosition() const;

    /// Get time elapsed since last frame in seconds.
    float deltaTime() const;

    /// True if the user has just resized the window.
    bool hasJustResized() const;

    /// Get or set the size of the window.
    Vector2 windowSize(Vector2);
    Vector2 windowSize() const;  /// ditto

    /// Get HiDPI scale of the window. A value of 1 should be equivalent to 96 DPI.
    Vector2 hidpiScale() const;

    /// Set area within the window items will be drawn to; any pixel drawn outside will be discarded.
    Rectangle area(Rectangle rect);
    Rectangle area() const;

    /// Restore the capability to draw anywhere in the window.
    void restoreArea();

    /// Get or set mouse cursor icon.
    GluiMouseCursor mouseCursor(GluiMouseCursor);
    GluiMouseCursor mouseCursor() const;

    /// Load a texture from memory or file.
    Texture loadTexture(Image image) @system;
    Texture loadTexture(string filename) @system;

    /// Destroy a texture created by this backend. `texture.destroy()` is the preferred way of calling this, since it
    /// will ensure the correct backend is called.
    void unloadTexture(Texture texture) @system;

    /// Draw a line.
    void drawLine(Vector2 start, Vector2 end, Color color);

    /// Draw a triangle, consisting of 3 vertices with counter-clockwise winding.
    void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color);

    /// Draw a rectangle.
    void drawRectangle(Rectangle rectangle, Color color);

    /// Draw a texture.
    void drawTexture(Texture texture, Vector2 position, Color tint)
    in (texture.backend is this, "Given texture comes from a different backend");

}

struct GluiMouseCursor {

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

        systemDefault = GluiMouseCursor(SystemCursors.systemDefault),
        none          = GluiMouseCursor(SystemCursors.none),
        pointer       = GluiMouseCursor(SystemCursors.pointer),
        crosshair     = GluiMouseCursor(SystemCursors.crosshair),
        text          = GluiMouseCursor(SystemCursors.text),
        allScroll     = GluiMouseCursor(SystemCursors.allScroll),
        resizeEW      = GluiMouseCursor(SystemCursors.resizeEW),
        resizeNS      = GluiMouseCursor(SystemCursors.resizeNS),
        resizeNESW    = GluiMouseCursor(SystemCursors.resizeNESW),
        resizeNWSE    = GluiMouseCursor(SystemCursors.resizeNWSE),
        notAllowed    = GluiMouseCursor(SystemCursors.notAllowed),

    }

    /// Use a system-provided cursor.
    SystemCursors system;
    // TODO user-provided cursor image

}

enum GluiMouseButton {
    none,
    left,         // Left (primary) mouse button.
    right,        // Right (secondary) mouse button.
    middle,       // Middle mouse button.
    extra1,       // Additional mouse button.
    extra2,       // ditto.
    forward,      // Mouse button going forward in browser history.
    back,         // Mouse button going back in browser history.
    scrollUp,     // Scroll one step up.
    scrollDown,   // Scroll one step down.
    scrollLeft,   // Scroll one step left.
    scrollRight,  // Scroll one step right.

    primary = left,
    secondary = right,

}

/// Check if the given mouse button is a scroll wheel step.
bool isScroll(GluiMouseButton button) {

    return button.scrollUp <= button && button <= button.scrollRight;

}

enum GluiGamepadButton {

    none,                // No such button
    dpadUp,              // Dpad up button.
    dpadRight,           // Dpad right button
    dpadDown,            // Dpad down button
    dpadLeft,            // Dpad left button
    triangle,            // Triangle (PS) or Y (Xbox)
    square,              // Square (PS) or X (Xbox)
    cross,               // Cross (PS) or A (Xbox)
    circle,              // Circle (PS) or B (Xbox)
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

enum GluiGamepadAxis {

    leftX,         // Left joystick, X axis.
    leftY,         // Left joystick, Y axis.
    rightX,        // Right joystick, X axis.
    rightY,        // Right joystick, Y axis.
    leftTrigger,   // Analog input for the left trigger.
    rightTrigger,  // Analog input for the right trigger.

}

enum GluiKeyboardKey {
    none               = 0,        // No key pressed
    apostrophe         = 39,       // '
    comma              = 44,       // ,
    dash               = comma,
    minus              = 45,       // -
    period             = 46,       // .
    slash              = 47,       // /
    digit0             = 48,       // 0
    digit1             = 49,       // 1
    digit2             = 50,       // 2
    digit3             = 51,       // 3
    digit4             = 52,       // 4
    digit5             = 53,       // 5
    digit6             = 54,       // 6
    digit7             = 55,       // 7
    digit8             = 56,       // 8
    digit9             = 57,       // 9
    semicolon          = 59,       // ;
    equal              = 61,       // =
    a                  = 65,       // A | a
    b                  = 66,       // B | b
    c                  = 67,       // C | c
    d                  = 68,       // D | d
    e                  = 69,       // E | e
    f                  = 70,       // F | f
    g                  = 71,       // G | g
    h                  = 72,       // H | h
    i                  = 73,       // I | i
    j                  = 74,       // J | j
    k                  = 75,       // K | k
    l                  = 76,       // L | l
    m                  = 77,       // M | m
    n                  = 78,       // N | n
    o                  = 79,       // O | o
    p                  = 80,       // P | p
    q                  = 81,       // Q | q
    r                  = 82,       // R | r
    s                  = 83,       // S | s
    t                  = 84,       // T | t
    u                  = 85,       // U | u
    v                  = 86,       // V | v
    w                  = 87,       // W | w
    x                  = 88,       // X | x
    y                  = 89,       // Y | y
    z                  = 90,       // Z | z
    leftBracket        = 91,       // [
    backslash          = 92,       // '\'
    rightBracket       = 93,       // ]
    backtick           = 96,       // `
    grave              = backtick,
    space              = 32,       // Space
    escape             = 256,      // Esc
    esc                = escape,
    enter              = 257,      // Enter
    tab                = 258,      // Tab
    backspace          = 259,      // Backspace
    insert             = 260,      // Ins
    del                = 261,      // Del
    delete_            = del,
    right              = 262,      // Cursor right
    left               = 263,      // Cursor left
    down               = 264,      // Cursor down
    up                 = 265,      // Cursor up
    pageUp             = 266,      // Page up
    pageDown           = 267,      // Page down
    home               = 268,      // Home
    end                = 269,      // End
    capsLock           = 280,      // Caps lock
    scrollLock         = 281,      // Scroll down
    numLock            = 282,      // Num lock
    printScreen        = 283,      // Print screen
    pause              = 284,      // Pause
    f1                 = 290,      // F1
    f2                 = 291,      // F2
    f3                 = 292,      // F3
    f4                 = 293,      // F4
    f5                 = 294,      // F5
    f6                 = 295,      // F6
    f7                 = 296,      // F7
    f8                 = 297,      // F8
    f9                 = 298,      // F9
    f10                = 299,      // F10
    f11                = 300,      // F11
    f12                = 301,      // F12
    leftShift          = 340,      // Shift left
    leftControl        = 341,      // Control left
    leftAlt            = 342,      // Alt left
    leftSuper          = 343,      // Super left
    rightShift         = 344,      // Shift right
    rightControl       = 345,      // Control right
    rightAlt           = 346,      // Alt right
    rightSuper         = 347,      // Super right
    contextMenu        = 348,      // Context menu
    keypad0            = 320,      // Keypad 0
    keypad1            = 321,      // Keypad 1
    keypad2            = 322,      // Keypad 2
    keypad3            = 323,      // Keypad 3
    keypad4            = 324,      // Keypad 4
    keypad5            = 325,      // Keypad 5
    keypad6            = 326,      // Keypad 6
    keypad7            = 327,      // Keypad 7
    keypad8            = 328,      // Keypad 8
    keypad9            = 329,      // Keypad 9
    keypadDecimal      = 330,      // Keypad .
    keypadDivide       = 331,      // Keypad /
    keypadMultiply     = 332,      // Keypad *
    keypadSubtract     = 333,      // Keypad -
    keypadSum          = 334,      // Keypad +
    keypadEnter        = 335,      // Keypad Enter
    keypadEqual        = 336,      // Keypad =
    androidBack        = 4,        // Android back button
    androidMenu        = 82,       // Android menu button
    volumeUp           = 24,       // Android volume up button
    volumeDown         = 25        // Android volume down button
    // Function keys for volume?

}

/// Generate an image filled with a given color.
///
/// Note: Image data is GC-allocated. Make sure to keep a reference alive when passing to the backend. Do not use
/// `UnloadImage` if using Raylib.
static Image generateColorImage(int width, int height, Color color) {

    // Generate each pixel
    auto data = new Color[width * height];
    data[] = color;

    // Prepare the result
    Image image;
    image.pixels = data;
    image.width = width;
    image.height = height;

    return image;

}

/// Image available to the CPU.
struct Image {

    /// Raw image data.
    Color[] pixels;
    int width, height;

    Vector2 size() const => Vector2(width, height);

    ref inout(Color) get(int x, int y) inout {

        return pixels[y * width + x];

    }

    /// Safer alternative to `get`, doesn't draw out of bounds.
    void set(int x, int y, Color color) {

        if (x < 0 || y < 0) return;
        if (x >= width || y >= height) return;

        get(x, y) = color;

    }

}

/// Represents a GPU texture.
///
/// Textures make use of manual memory management.
struct Texture {

    /// Backend that created this texture.
    GluiBackend backend;

    /// GPU/backend ID of the texture.
    uint id;
    int width;
    int height;

    bool opEquals(const Texture other) const

        => id == other.id
        && width == other.width
        && height == other.height;

    /// Draw this texture.
    void draw(Vector2 position, Color tint = color!"fff") {

        backend.drawTexture(this, position, tint);

    }

    /// Destroy this texture.
    void destroy() @system {

        if (backend is null) return;

        backend.unloadTexture(this);
        backend = null;
        id = 0;

    }

}

/// Get a hex code from color.
string toHex(string prefix = "#")(Color color) {

    import std.format;

    // Full alpha, use a six digit code
    if (color.a == 0xff) {

        return format!(prefix ~ "%02x%02x%02x")(color.r, color.g, color.b);

    }

    // Include alpha otherwise
    else return format!(prefix ~ "%02x%02x%02x%02x")(color.tupleof);

}

unittest {

    // No relevant alpha
    assert(color("fff").toHex == "#ffffff");
    assert(color("ffff").toHex == "#ffffff");
    assert(color("ffffff").toHex == "#ffffff");
    assert(color("ffffffff").toHex == "#ffffff");
    assert(color("fafbfc").toHex == "#fafbfc");
    assert(color("123").toHex == "#112233");

    // Alpha set
    assert(color("c0fe").toHex == "#cc00ffee");
    assert(color("1234").toHex == "#11223344");
    assert(color("0000").toHex == "#00000000");
    assert(color("12345678").toHex == "#12345678");

}

/// Create a color from hex code.
Color color(string hexCode)() {

    return color(hexCode);

}

/// ditto
Color color(string hexCode) pure {

    import std.string : chompPrefix;
    import std.format : format, formattedRead;

    // Remove the # if there is any
    const hex = hexCode.chompPrefix("#");

    Color result;
    result.a = 0xff;

    switch (hex.length) {

        // 4 digit RGBA
        case 4:
            formattedRead!"%x"(hex[3..4], result.a);
            result.a *= 17;

            // Parse the rest like RGB
            goto case;

        // 3 digit RGB
        case 3:
            formattedRead!"%x"(hex[0..1], result.r);
            formattedRead!"%x"(hex[1..2], result.g);
            formattedRead!"%x"(hex[2..3], result.b);
            result.r *= 17;
            result.g *= 17;
            result.b *= 17;
            break;

        // 8 digit RGBA
        case 8:
            formattedRead!"%x"(hex[6..8], result.a);
            goto case;

        // 6 digit RGB
        case 6:
            formattedRead!"%x"(hex[0..2], result.r);
            formattedRead!"%x"(hex[2..4], result.g);
            formattedRead!"%x"(hex[4..6], result.b);
            break;

        default:
            assert(false, "Invalid hex code length");

    }

    return result;

}

unittest {

    import std.exception;

    assert(color!"#123" == Color(0x11, 0x22, 0x33, 0xff));
    assert(color!"#1234" == Color(0x11, 0x22, 0x33, 0x44));
    assert(color!"1234" == Color(0x11, 0x22, 0x33, 0x44));
    assert(color!"123456" == Color(0x12, 0x34, 0x56, 0xff));
    assert(color!"2a5592f0" == Color(0x2a, 0x55, 0x92, 0xf0));

    assertThrown(color!"ag5");

}

/// Set the alpha channel for the given color, as a float.
Color setAlpha(Color color, float alpha) {

    import std.algorithm : clamp;

    color.a = cast(ubyte) clamp(ubyte.max * alpha, 0, ubyte.max);
    return color;

}

/// Blend two colors together; apply `top` on top of the `bottom` color. If `top` has maximum alpha, returns `top`. If
/// alpha is zero, returns `bottom`.
Color alphaBlend(Color bottom, Color top) {

    auto topA = cast(float) top.a / ubyte.max;
    auto bottomA = (1 - topA) * cast(float) bottom.a / ubyte.max;

    return Color(
        cast(ubyte) (bottom.r * bottomA + top.r * topA),
        cast(ubyte) (bottom.g * bottomA + top.g * topA),
        cast(ubyte) (bottom.b * bottomA + top.b * topA),
        cast(ubyte) (bottom.a * bottomA + top.a * topA),
    );

}

version (Have_raylib_d) {

    import raylib;

    debug (Glui_BuildMessages) {
        pragma(msg, "Glui: Using Raylib 5 as the default backend");
    }

    static this() {

        defaultGluiBackend = new Raylib5Backend;

    }

    alias Rectangle = raylib.Rectangle;
    alias Vector2 = raylib.Vector2;
    alias Color = raylib.Color;

}

else {

    debug (Glui_BuildMessages) {
        pragma(msg, "Glui: No built-in backend in use");
    }

    struct Vector2 {

        float x, y;

        mixin Linear;

    }

    struct Rectangle {

        float x, y;
        float width, height;

        alias w = width;
        alias h = height;

    }

    struct Color {

        ubyte r, g, b, a;

    }

    /// `mixin Linear` taken from [raylib-d](https://github.com/schveiguy/raylib-d), reformatted and without Rotor3
    /// support.
    ///
    /// Licensed under the [z-lib license](https://github.com/schveiguy/raylib-d/blob/master/LICENSE).
    private mixin template Linear() {

        private static alias T = typeof(this);
        private import std.traits : FieldNameTuple;

        static T zero() {

            enum fragment = {
                string result;
                static foreach(i; 0 .. T.tupleof.length)
                    result ~= "0,";
                return result;
            }();

            return mixin("T(", fragment, ")");
        }

        static T one() {

            enum fragment = {
                string result;
                static foreach(i; 0 .. T.tupleof.length)
                    result ~= "1,";
                return result;
            }();
            return mixin("T(", fragment, ")");

        }

        inout T opUnary(string op)() if (op == "+" || op == "-") {

            enum fragment = {
                string result;
                static foreach(fn; FieldNameTuple!T)
                    result ~= op ~ fn ~ ",";
                return result;
            }();
            return mixin("T(", fragment, ")");

        }

        inout T opBinary(string op)(inout T rhs) if (op == "+" || op == "-") {

            enum fragment = {
                string result;
                foreach(fn; FieldNameTuple!T)
                    result ~= fn ~ op ~ "rhs." ~ fn ~ ",";
                return result;
            }();
            return mixin("T(", fragment, ")");

        }

        ref T opOpAssign(string op)(inout T rhs) if (op == "+" || op == "-") {

            foreach (field; FieldNameTuple!T)
                mixin(field, op,  "= rhs.", field, ";");

            return this;

        }

        inout T opBinary(string op)(inout float rhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {

            enum fragment = {
                string result;
                foreach(fn; FieldNameTuple!T)
                    result ~= fn ~ op ~ "rhs,";
                return result;
            }();
            return mixin("T(", fragment, ")");

        }

        inout T opBinaryRight(string op)(inout float lhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {

            enum fragment = {
                string result;
                foreach(fn; FieldNameTuple!T)
                    result ~= "lhs" ~ op ~ fn ~ ",";
                return result;
            }();
            return mixin("T(", fragment, ")");

        }

        ref T opOpAssign(string op)(inout float rhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {

            foreach (field; FieldNameTuple!T)
                mixin(field, op, "= rhs;");
            return this;

        }
    }

}
