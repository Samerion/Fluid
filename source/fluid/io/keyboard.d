/// This module contains interfaces for handling keyboard actions.
module fluid.io.keyboard;

import fluid.future.context;

import fluid.io.action;

@safe:

/// I/O interface for emitting keyboard events.
///
/// When a key is pressed on a keyboard device, it will emit an active `InputEvent`. While it is held down,
/// it will continue to emit events every frame, however they will be marked inactive.
///
/// A `KeyboardIO` system will usually pass events to a `FocusIO` system it is child of.
interface KeyboardIO : IO {

    /// Get a keyboard input event code.
    /// Params:
    ///     key = Key to get the code for.
    /// Returns:
    ///     The created input event code.
    static InputEventCode getCode(Key key) {

        return InputEventCode(ioID!KeyboardIO, key);

    }

    /// A shortcut for getting input event codes that are known at compile time. Handy for tests.
    /// Returns: A struct with event code for each member, corresponding to members of `Key`.
    static codes() {

        static struct Codes {
            static InputEventCode opDispatch(string name)() {
                return getCode(__traits(getMember, KeyboardIO.Key, name));
            }
        }

        return Codes();

    }

    ///
    @("KeyboardIO.codes resolves into input event codes")
    unittest {

        assert(KeyboardIO.codes.comma == KeyboardIO.getCode(KeyboardIO.Key.comma));
        assert(KeyboardIO.codes.a == KeyboardIO.getCode(KeyboardIO.Key.a));

    }

    /// Create a keyboard input event that can be passed to a `FocusIO` or `ActionIO` handler.
    /// Params:
    ///     key      = Key that is held down.
    ///     isActive = True if the key was just pressed.
    /// Returns:
    ///     The created input event.
    static InputEvent createEvent(Key key, bool isActive) {

        const code = getCode(key);
        return InputEvent(code, isActive);

    }

    enum Key {
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

}
