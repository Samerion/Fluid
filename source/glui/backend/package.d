/// This module handles input/output facilities Glui requires to operate. It connects backends like Raylib, exposing
/// them under a common interface so they can be changed at will.
///
/// Glui comes with a built-in interface for Raylib.
module glui.backend;


@safe:


alias VoidDelegate = void delegate() @safe;


interface GluiBackend {

    // Check if the given mouse button has just been pressed/released or, if it's held down or not (up).
    bool isPressed(GluiMouseButton) const;
    bool isReleased(GluiMouseButton) const;
    bool isDown(GluiMouseButton) const;
    bool isUp(GluiMouseButton) const;

    // Check if the given keyboard key has just been pressed/released or, if it's held down or not (up).
    bool isPressed(GluiKeyboardKey) const;
    bool isReleased(GluiKeyboardKey) const;
    bool isDown(GluiKeyboardKey) const;
    bool isUp(GluiKeyboardKey) const;

    /// If true, the given keyboard key has been virtually pressed again, through a long-press.
    bool isRepeated(GluiKeyboardKey) const;

    /// Get/set mouse position
    Vector2 mousePosition(Vector2);
    Vector2 mousePosition() const;

    /// True if the user has just resized the window.
    bool hasJustResized() const;

    /// Get or set the size of the window.
    Vector2 windowSize(Vector2);
    Vector2 windowSize() const;  /// ditto

    /// Get or set mouse cursor icon.
    GluiMouseCursor mouseCursor(GluiMouseCursor);
    GluiMouseCursor mouseCursor() const;

    // Draw a rectangle
    void drawRectangle(Rectangle rectangle, Color color);

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
    left,     // Left (primary) mouse button.
    right,    // Right (secondary) mouse button.
    middle,   // Middle mouse button.
    extra1,   // Additional mouse button.
    extra2,   // ditto.
    forward,  // Mouse button going forward in browser history.
    back,     // Mouse button going back in browser history.

    primary = left,
    secondary = right,

}

enum GluiKeyboardKey {
    none               = 0,        // No key pressed
    apostrophe         = 39,       // '
    comma              = 44,       // ,
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
    back               = 4,        // Android back button
    menu               = 82,       // Android menu button
    volumeUp           = 24,       // Android volume up button
    volumeDown         = 25        // Android volume down button
    // Function keys for volume?

}

static GluiBackend defaultGluiBackend;

version (Have_raylib_d) {

    debug (Glui_BuildMessages) {
        pragma(msg, "Building with Raylib 5 support");
    }

    public import glui.backend.raylib5;

    static this() {

        defaultGluiBackend = new Raylib5Backend;

    }

}

else {

    debug (Glui_BuildMessages) {
        pragma(msg, "Building with no backend");
    }

    struct Vector2 {

        float x, y;

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

    struct Image {

        /// Raw image data.
        ubyte[] data;
        int width, height;

        // TODO pixel format

        Vector2 size() const => Vector2(width, height);

    }

}
