module fluid.backend_interface;

import core.time;

import fluid.backend;

@safe:

shared FluidBackend delegate() @safe getDefaultFluidBackend = () => null;

FluidBackend defaultFluidBackend() {
    return getDefaultFluidBackend();
}

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
