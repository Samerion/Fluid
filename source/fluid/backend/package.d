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

import fluid.io.mouse;
import fluid.io.keyboard;

public import fluid.types;
public import fluid.backend.raylib5;
public import fluid.backend.headless;

alias KeyboardKey = KeyboardIO.Key;
alias MouseButton = MouseIO.Button;

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

    bool opEquals(FluidBackend) const;

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

/// To simplify setup in some scenarios, Fluid provides a uniform `run` function to immediately display UI and start 
/// the event loop. This function is provided by the backend using this optional interface.
///
/// For `run` to use this backend, it has to be configured as the default backend or be passed explicitly to the `run`
/// function.
interface FluidEntrypointBackend : FluidBackend {

    import fluid.node : Node;

    /// Start a Fluid GUI app using this backend.
    ///
    /// This will draw the user interface and respond to input events in a loop, until the root node is marked for 
    /// removal (`remove()`).
    ///
    /// See_Also: `fluid.node.run`
    /// Params:
    ///     root = Node to function as the root of the user interface.
    void run(Node root);

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
    bool isDestroyed() @system {
        return _references.atomicLoad == 0;
    }

    /// Check if the texture has been disowned by the backend. A disowned tombstone refers to a texture that has been
    /// freed.
    private bool isDisowned() @system {
        return _disowned.atomicLoad;
    }

    /// Get number of references to this tombstone.
    private int references() @system {
        return _references.atomicLoad;
    }

    /// Get the backend owning this texture.
    inout(shared FluidBackend) backend() inout {
        return _backend;
    }

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

    bool opEquals(const Texture other) const {
        return id == other.id
            && width == other.width
            && height == other.height
            && dpiX == other.dpiX
            && dpiY == other.dpiY;

    }

    version (Have_raylib_d)
    void opAssign(raylib.Texture rayTexture) @system {
        this = rayTexture.toFluid();
    }

    /// Get the backend for this texture. Doesn't work after freeing the tombstone.
    inout(FluidBackend) backend() inout @trusted {
        return cast(inout FluidBackend) tombstone.backend;
    }

    /// DPI value of the texture.
    Vector2 dpi() const {
        return Vector2(dpiX, dpiY);
    }

    /// Get texture size as a vector.
    Vector2 canvasSize() const {
        return Vector2(width, height);
    }

    /// Get the size the texture will occupy within the viewport.
    Vector2 viewportSize() const {
        return Vector2(
            width * 96 / dpiX,
            height * 96 / dpiY
        );
    }

    /// Update the texture to match the given image.
    void update(Image image) @system {

        backend.updateTexture(this, image);

    }

    /// Draw this texture.
    void draw(Vector2 position, Color tint = Color(0xff, 0xff, 0xff, 0xff)) {

        auto rectangle = Rectangle(position.tupleof, viewportSize.tupleof);

        backend.drawTexture(this, rectangle, tint);

    }

    void draw(Rectangle rectangle, Color tint = Color(0xff, 0xff, 0xff, 0xff)) {

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
    this(this) @trusted {

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

        static Raylib5Backend backend;

        if (backend)
            return backend;
        else
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
