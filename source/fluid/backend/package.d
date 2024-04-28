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

public import fluid.backend.raylib5;
public import fluid.backend.headless;

version (Have_raylib_d) public static import raylib;


@safe:


alias VoidDelegate = void delegate() @safe;

FluidBackend defaultFluidBackend();

/// `FluidBackend` is an interface making it possible to bind Fluid to a library other than Raylib.
///
/// The default unit in graphical space is a **pixel** (`px`), here defined as **1/96 of an inch**. This is unless
/// stated otherwise, as in `Texture`.
///
/// Warning: Backend API is unstable and functions may be added or removed with no prior warning.
interface FluidBackend {

    /// Get system's double click time.
    final Duration doubleClickTime() const {

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
    final Vector2 hidpiScale() const {

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
    protected void unloadTexture(uint id) @system;

    /// ditto
    final void unloadTexture(Texture texture) @system {

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

/// Struct that maintains a registry of all allocated textures. It's used to finalize textures once they have been
/// marked for destruction. This makes it possible to mark them from any thread, while the reaper runs only on the main
/// thread, ensuring thread safety in OpenGL backends.
struct TextureReaper {

    /// Number of cycles between runs of the reaper.
    int period = 60 * 5;

    int cycleAccumulator;

    @system shared(TextureTombstone)*[uint] textures;

    @disable this(ref TextureReaper);
    @disable this(this);

    ~this() @trusted {

        destroyAll();

    }

    /// Create a tombstone.
    shared(TextureTombstone)* makeTombstone(FluidBackend backend, uint textureID) @trusted {

        return textures[textureID] = TextureTombstone.make(backend);

    }

    /// Count number of cycles since last collection and collect if configured period has passed.
    void check() {

        // Count cycles
        if (++cycleAccumulator >= period) {

            // Run collection
            collect();

        }

    }

    /// Collect all destroyed textures immediately.
    void collect() @trusted {

        // Reset the cycle accumulator
        cycleAccumulator = 0;

        // Find all destroyed textures
        foreach (id, tombstone; textures) {

            if (!tombstone.isDestroyed) continue;

            auto backend = cast() tombstone.backend;

            // Unload the texture
            backend.unloadTexture(id);

            // Disown the tombstone and remove it from the registry
            tombstone.markDisowned();
            textures.remove(id);

        }

    }

    /// Destroy all textures.
    void destroyAll() @system {

        cycleAccumulator = 0;
        scope (exit) textures.clear();

        // Find all textures
        foreach (id, tombstone; textures) {

            auto backend = cast() tombstone.backend;

            // Unload the texture, even if it wasn't marked for deletion
            backend.unloadTexture(id);
            // TODO Should this be done? The destructor may be called from the GC. Maybe check if it was?
            //      Test this!

            // Disown all textures
            tombstone.markDisowned();

        }

    }

}

/// Tombstones are used to ensure textures are freed on the same thread they have been created on.
///
/// Tombstones are kept alive until the texture is explicitly destroyed and then finalized (disowned) from the main
/// thread by a periodically-running `TextureReaper`. This is necessary to make Fluid safe in multithreaded
/// environments.
shared struct TextureTombstone {

    import core.memory;
    import core.atomic;
    import core.stdc.stdlib;

    /// Backend that created this texture.
    private FluidBackend _backend;

    private int _references = 1;
    private bool _disowned;

    @disable this(this);

    static TextureTombstone* make(FluidBackend backend) @system {

        import core.exception;

        // Allocate the tombstone
        auto data = malloc(TextureTombstone.sizeof);
        if (data is null) throw new OutOfMemoryError("Failed to allocate a tombstone");

        // Initialize the tombstone
        shared tombstone = cast(shared TextureTombstone*) data;
        *tombstone = TextureTombstone.init;
        tombstone._backend = cast(shared) backend;

        assert(tombstone.references == 1);

        // Make sure the backend isn't freed while the tombstone is alive
        GC.addRoot(cast(void*) backend);

        return tombstone;

    }

    /// Check if a request for destruction has been made for the texture.
    bool isDestroyed() @system => _references.atomicLoad == 0;

    /// Check if the texture has been disowned by the backend. A disowned tombstone refers to a texture that has been
    /// freed.
    private bool isDisowned() @system => _disowned.atomicLoad;

    /// Get number of references to this tombstone.
    private int references() @system => _references.atomicLoad;

    /// Get the backend owning this texture.
    inout(shared FluidBackend) backend() inout => _backend;

    /// Mark the texture as destroyed.
    void markDestroyed() @system {

        assert(!isDisowned || !isDestroyed, "Texture: Double destroy()");

        _references.atomicFetchSub(1);
        tryDestroy();

    }

    /// Mark the texture as disowned.
    private void markDisowned() @system {

        assert(!isDisowned || !isDestroyed);

        _disowned.atomicStore(true);
        tryDestroy();

    }

    /// Mark the texture as copied.
    private void markCopied() @system {

        _references.atomicFetchAdd(1);

    }

    /// As soon as the texture is both marked for destruction and disowned, the tombstone controlling its life is
    /// destroyed.
    ///
    /// There are two relevant scenarios:
    ///
    /// * The texture is marked for destruction via a tombstone, then finalized from the main thread and disowned.
    /// * The texture is finalized after the backend (for example, if they are both destroyed during the same GC
    ///   collection). The backend disowns and frees the texture. The tombstone, however, remains alive to
    ///   witness marking the texture as deleted.
    ///
    /// In both scenarios, this behavior ensures the tombstone will be freed.
    private void tryDestroy() @system {

        // Destroyed and disowned
        if (isDestroyed && isDisowned) {

            GC.removeRoot(cast(void*) _backend);
            free(cast(void*) &this);

        }

    }

}

@system
unittest {

    // This unittest checks if textures will be correctly destroyed, even if the destruction call comes from another
    // thread.

    import std.concurrency;
    import fluid.space;
    import fluid.image_view;

    auto io = new HeadlessBackend;
    auto image = imageView("logo.png");
    auto root = vspace(image);

    // Draw the frame once to let everything load
    root.io = io;
    root.draw();

    // Tune the reaper to run every frame
    io.reaper.period = 1;

    // Get the texture
    auto texture = image.release();
    auto textureID = texture.id;
    auto tombstone = texture.tombstone;

    // Texture should be allocated and assigned a tombstone
    assert(texture.backend is io);
    assert(!texture.tombstone.isDestroyed);
    assert(io.isTextureValid(texture));

    // Destroy the texture on another thread
    spawn((shared Texture sharedTexture) {

        auto texture = cast() sharedTexture;
        texture.destroy();
        ownerTid.send(true);

    }, cast(shared) texture);

    // Wait for confirmation
    receiveOnly!bool;

    // The texture should be marked for deletion but remain alive
    assert(texture.tombstone.isDestroyed);
    assert(io.isTextureValid(texture));

    // Draw a frame, during which the reaper should destroy the texture
    io.nextFrame;
    root.children = [];
    root.updateSize();
    root.draw();

    assert(!io.isTextureValid(texture));
    // There is no way to test if the tombstone has been freed

}

@system
unittest {

    // This unittest checks if tombstones work correctly even if the backend is destroyed before the texture.

    import std.concurrency;
    import core.atomic;
    import fluid.image_view;

    auto io = new HeadlessBackend;
    auto root = imageView("logo.png");

    // Load the texture and draw
    root.io = io;
    root.draw();

    // Destroy the backend
    destroy(io);

    auto texture = root.release();

    // The texture should have been automatically freed, but not marked for destruction
    assert(!texture.tombstone.isDestroyed);
    assert(texture.tombstone._disowned.atomicLoad);

    // Now, destroy the image
    // If this operation succeeds, we're good
    destroy(root);
    // There is no way to test if the tombstone and texture have truly been freed

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

    return Image(data, width, height);

}

/// Generate a paletted image filled with 0-index pixels of given alpha value.
static Image generatePalettedImage(int width, int height, ubyte alpha) {

    auto data = new PalettedColor[width * height];
    data[] = PalettedColor(alpha, 0);

    return Image(data, width, height);

}

/// Generate an alpha mask filled with given value.
static Image generateAlphaMask(int width, int height, ubyte value) {

    auto data = new ubyte[width * height];
    data[] = value;

    return Image(data, width, height);

}

/// A paletted pixel, for use in `palettedAlpha` images; Stores images using an index into a palette, along with an
/// alpha value.
struct PalettedColor {

    ubyte alpha;
    ubyte index;

}

/// Image available to the CPU.
struct Image {

    enum Format {

        /// RGBA, 8 bit per channel (32 bits per pixel).
        rgba,

        /// Paletted image with alpha channel (16 bits per pixel)
        palettedAlpha,

        /// Alpha-only image/mask (8 bits per pixel).
        alpha,

    }

    Format format;

    /// Image data. Make sure to access data relevant to the current format.
    ///
    /// Each format has associated data storage. `rgba` has `rgbaPixels`, `palettedAlpha` has `palettedAlphaPixels` and
    /// `alpha` has `alphaPixels`.
    Color[] rgbaPixels;

    /// ditto
    PalettedColor[] palettedAlphaPixels;

    /// ditto
    ubyte[] alphaPixels;

    /// Palette data, if relevant. Access into an invalid palette index is equivalent to full white.
    ///
    /// For `palettedAlpha` images (and `PalettedColor` in general), the alpha value of each color in the palette is
    /// ignored.
    Color[] palette;

    int width, height;

    /// Create an RGBA image.
    this(Color[] rgbaPixels, int width, int height) {

        this.format = Format.rgba;
        this.rgbaPixels = rgbaPixels;
        this.width = width;
        this.height = height;

    }

    /// Create a paletted image.
    this(PalettedColor[] palettedAlphaPixels, int width, int height) {

        this.format = Format.palettedAlpha;
        this.palettedAlphaPixels = palettedAlphaPixels;
        this.width = width;
        this.height = height;

    }

    /// Create an alpha mask.
    this(ubyte[] alphaPixels, int width, int height) {

        this.format = Format.alpha;
        this.alphaPixels = alphaPixels;
        this.width = width;
        this.height = height;

    }

    Vector2 size() const {

        return Vector2(width, height);

    }

    int area() const {

        return width * height;

    }

    /// Get a palette entry at given index.
    Color paletteColor(PalettedColor pixel) const {

        // Valid index, return the color; Set alpha to match the pixel
        if (pixel.index < palette.length)
            return palette[pixel.index].setAlpha(pixel.alpha);

        // Invalid index, return white
        else
            return Color(0xff, 0xff, 0xff, pixel.alpha);

    }

    /// Get data of the image in raw form.
    inout(void)[] data() inout {

        final switch (format) {

            case Format.rgba:
                return rgbaPixels;
            case Format.palettedAlpha:
                return palettedAlphaPixels;
            case Format.alpha:
                return alphaPixels;

        }

    }

    /// Get color at given position. Position must be in image bounds.
    Color get(int x, int y) const {

        const index = y * width + x;

        final switch (format) {

            case Format.rgba:
                return rgbaPixels[index];
            case Format.palettedAlpha:
                return paletteColor(palettedAlphaPixels[index]);
            case Format.alpha:
                return Color(0xff, 0xff, 0xff, alphaPixels[index]);

        }

    }

    /// Set color at given position. Does nothing if position is out of bounds.
    ///
    /// The `set(int, int, Color)` overload only supports true color images. For paletted images, use
    /// `set(int, int, PalettedColor)`. The latter can also be used for building true color images using a palette, if
    /// one is supplied in the image at the time.
    void set(int x, int y, Color color) {

        if (x < 0 || y < 0) return;
        if (x >= width || y >= height) return;

        const index = y * width + x;

        final switch (format) {

            case Format.rgba:
                rgbaPixels[index] = color;
                return;
            case Format.palettedAlpha:
                assert(false, "Unsupported image format: Cannot `set` pixels by color in a paletted image.");
            case Format.alpha:
                alphaPixels[index] = color.a;
                return;

        }

    }

    /// ditto
    void set(int x, int y, PalettedColor entry) {

        if (x < 0 || y < 0) return;
        if (x >= width || y >= height) return;

        const index = y * width + x;
        const color = paletteColor(entry);

        final switch (format) {

            case Format.rgba:
                rgbaPixels[index] = color;
                return;
            case Format.palettedAlpha:
                palettedAlphaPixels[index] = entry;
                return;
            case Format.alpha:
                alphaPixels[index] = color.a;
                return;

        }

    }

    /// Clear the image, replacing every pixel with given color.
    ///
    /// The `clear(Color)` overload only supports true color images. For paletted images, use `clear(PalettedColor)`.
    /// The latter can also be used for building true color images using a palette, if one is supplied in the image at
    /// the time.
    void clear(Color color) {

        final switch (format) {

            case Format.rgba:
                rgbaPixels[] = color;
                return;
            case Format.palettedAlpha:
                assert(false, "Unsupported image format: Cannot `clear` by color in a paletted image.");
            case Format.alpha:
                alphaPixels[] = color.a;
                return;

        }

    }

    /// ditto
    void clear(PalettedColor entry) {

        const color = paletteColor(entry);

        final switch (format) {

            case Format.rgba:
                rgbaPixels[] = color;
                return;
            case Format.palettedAlpha:
                palettedAlphaPixels[] = entry;
                return;
            case Format.alpha:
                alphaPixels[] = color.a;
                return;

        }

    }

}


/// Image or texture can be rendered by Fluid, for example, a texture stored in VRAM.
///
/// Textures make use of manual memory management. See `TextureGC` for a GC-managed texture.
struct Texture {

    /// Tombstone for this texture
    shared(TextureTombstone)* tombstone;

    /// Format of the texture.
    Image.Format format;

    /// GPU/backend ID of the texture.
    uint id;

    /// Width and height of the texture, **in dots**. The meaning of a dot is defined by `dpiX` and `dpiY`
    int width, height;

    /// Dots per inch for the X and Y axis. Defaults to 96, thus making a dot in the texture equivalent to a pixel.
    int dpiX = 96, dpiY = 96;

    /// If relevant, the texture is to use this palette.
    Color[] palette;

    bool opEquals(const Texture other) const

        => id == other.id
        && width == other.width
        && height == other.height
        && dpiX == other.dpiX
        && dpiY == other.dpiY;

    version (Have_raylib_d)void opAssign(raylib.Texture rayTexture) @system {
        this = rayTexture.toFluid();
    }

    /// Get the backend for this texture. Doesn't work after freeing the tombstone.
    inout(FluidBackend) backend() inout @trusted

        => cast(inout FluidBackend) tombstone.backend;

    /// DPI value of the texture.
    Vector2 dpi() const

        => Vector2(dpiX, dpiY);

    /// Get texture size as a vector.
    Vector2 canvasSize() const

        => Vector2(width, height);

    /// Get the size the texture will occupy within the viewport.
    Vector2 viewportSize() const

        => Vector2(
            width * 96 / dpiX,
            height * 96 / dpiY
        );

    /// Update the texture to match the given image.
    void update(Image image) @system {

        backend.updateTexture(this, image);

    }

    /// Draw this texture.
    void draw(Vector2 position, Color tint = color!"fff") {

        auto rectangle = Rectangle(position.tupleof, viewportSize.tupleof);

        backend.drawTexture(this, rectangle, tint);

    }

    void draw(Rectangle rectangle, Color tint = color!"fff") {

        backend.drawTexture(this, rectangle, tint);

    }

    /// Destroy this texture. This function is thread-safe.
    void destroy() @system {

        if (tombstone is null) return;

        tombstone.markDestroyed();
        tombstone = null;
        id = 0;

    }

}

/// Wrapper over `Texture` that automates destruction via GC or RAII.
struct TextureGC {

    /// Underlying texture. Lifetime is bound to this struct.
    Texture texture;

    alias texture this;

    /// Load a texture from filename.
    this(FluidBackend backend, string filename) @trusted {

        this.texture = backend.loadTexture(filename);

    }

    /// Load a texture from image data.
    this(FluidBackend backend, Image data) @trusted {

        this.texture = backend.loadTexture(data);

    }

    /// Move constructor for TextureGC; increment the reference counter for the texture.
    ///
    /// While I originally did not intend to implement reference counting, it is necessary to make TextureGC work in
    /// dynamic arrays. Changing the size of the array will copy the contents without performing a proper move of the
    /// old items. The postblit is the only kind of move constructor that will be called in this case, and a copy
    /// constructor does not do its job.
    this(this) @system {

        if (tombstone)
        tombstone.markCopied();

    }

    @system
    unittest {

        import std.string;

        // This tests using TextureGC inside of a dynamic array, especially after resizing. See documentation for
        // the postblit above.

        // Test two variants:
        // * One, where we rely on the language to finalize the copied value
        // * And one, where we manually destroy the value
        foreach (explicitDestruction; [false, true]) {

            void makeCopy(TextureGC[] arr) {

                // Create the copy
                auto copy = arr;

                assert(sameHead(arr, copy));

                // Expand the array, creating another
                copy.length = 1024;

                assert(!sameHead(arr, copy));

                // References to tombstones exist in both arrays now
                assert(!copy[0].tombstone.isDestroyed);
                assert(!arr[0].tombstone.isDestroyed);

                // The copy should be marked as moved
                assert(copy[0].tombstone.references == 2);
                assert(arr[0].tombstone.references == 2);

                // Destroy the tombstone
                if (explicitDestruction) {

                    auto tombstone = copy[0].tombstone;

                    copy[0].destroy();
                    assert(tombstone.references == 1);
                    assert(!tombstone.isDestroyed);

                }

                // Forget about the copy
                copy = null;

            }

            static void trashStack() {

                import core.memory;

                // Destroy the stack to get rid of any references to `copy`
                ubyte[2048] garbage;

                // Collect it, make sure the tombstone gets eaten
                GC.collect();

            }

            auto io = new HeadlessBackend;
            auto image = generateColorImage(10, 10, color("#fff"));
            auto arr = [
                TextureGC(io, image),
                TextureGC.init,
            ];

            makeCopy(arr);
            trashStack();

            assert(!arr[0].tombstone.isDestroyed, "Tombstone of a live texture was destroyed after copying an array"
                ~ format!" (explicitDestruction %s)"(explicitDestruction));

            io.reaper.collect();

            assert(io.isTextureValid(arr[0]));
            assert(!arr[0].tombstone.isDestroyed);
            assert(!arr[0].tombstone.isDisowned);
            assert(arr[0].tombstone.references == 1);

        }

    }

    @system
    unittest {

        auto io = new HeadlessBackend;
        auto image = generateColorImage(10, 10, color("#fff"));
        auto arr = [
            TextureGC(io, image),
            TextureGC.init,
        ];
        auto copy = arr.dup;

        assert(arr[0].tombstone.references == 2);

        io.reaper.collect();

        assert(io.isTextureValid(arr[0]));

    }

    ~this() @trusted {

        texture.destroy();

    }

    /// Release the texture, moving it to manual management.
    Texture release() @system {

        auto result = texture;
        texture = texture.init;
        return result;

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
///
/// BUG: This function is currently broken and returns incorrect results.
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

/// Multiple color values.
Color multiply(Color a, Color b) {

    return Color(
        cast(ubyte) (a.r * b.r / 255.0),
        cast(ubyte) (a.g * b.g / 255.0),
        cast(ubyte) (a.b * b.b / 255.0),
        cast(ubyte) (a.a * b.a / 255.0),
    );

}

unittest {

    assert(multiply(color!"#fff", color!"#a00") == color!"#a00");
    assert(multiply(color!"#1eff00", color!"#009bdd") == color!"#009b00");
    assert(multiply(color!"#aaaa", color!"#1234") == color!"#0b16222d");

}

version (unittest) {

    debug (Fluid_BuildMessages) {
        pragma(msg, "Fluid: Using headless as the default backend (unittest)");
    }

    FluidBackend defaultFluidBackend() {

        return new HeadlessBackend;

    }

}

else version (Have_raylib_d) {

    debug (Fluid_BuildMessages) {
        pragma(msg, "Fluid: Using Raylib 5 as the default backend");
    }

    FluidBackend defaultFluidBackend() {

        return new Raylib5Backend;

    }

}

else {

    debug (Fluid_BuildMessages) {
        pragma(msg, "Fluid: No built-in backend in use");
    }

    FluidBackend defaultFluidBackend() {

        return null;

    }

}

// Structures
version (Have_raylib_d) {

    debug (Fluid_BuildMessages) {
        pragma(msg, "Fluid: Using Raylib core structures");
    }

    import raylib;

    alias Rectangle = raylib.Rectangle;
    alias Vector2 = raylib.Vector2;
    alias Color = raylib.Color;

}

else {

    struct Vector2 {

        float x = 0;
        float y = 0;

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