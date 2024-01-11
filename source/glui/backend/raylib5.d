module glui.backend.raylib5;

version (Have_raylib_d):

debug (Glui_BuildMessages) {
    pragma(msg, "Glui: Building with Raylib 5 support");
}

import raylib;

import std.range;
import std.algorithm;

import glui.backend;

public import raylib : Vector2, Rectangle, Color;


@safe:


class Raylib5Backend : GluiBackend {

    private {

        TextureReaper _reaper;
        GluiMouseCursor lastMouseCursor;
        Rectangle drawArea;
        float _scale = 1;

    }

    @trusted {

        bool isPressed(GluiMouseButton button) const
            => isScroll(button)
            ?  isScrollPressed(button)
            :  IsMouseButtonPressed(button.toRaylib);
        bool isReleased(GluiMouseButton button) const
            => isScroll(button)
            ?  isScrollPressed(button)
            :  IsMouseButtonReleased(button.toRaylib);
        bool isDown(GluiMouseButton button) const
            => isScroll(button)
            ?  isScrollPressed(button)
            :  IsMouseButtonDown(button.toRaylib);
        bool isUp(GluiMouseButton button) const
            => isScroll(button)
            ?  !isScrollPressed(button)
            :  IsMouseButtonUp(button.toRaylib);

        bool isPressed(GluiKeyboardKey key) const => IsKeyPressed(key.toRaylib);
        bool isReleased(GluiKeyboardKey key) const => IsKeyReleased(key.toRaylib);
        bool isDown(GluiKeyboardKey key) const => IsKeyDown(key.toRaylib);
        bool isUp(GluiKeyboardKey key) const => IsKeyUp(key.toRaylib);
        bool isRepeated(GluiKeyboardKey key) const => IsKeyPressedRepeat(key.toRaylib);

        dchar inputCharacter() => cast(dchar) GetCharPressed();

        int isPressed(GluiGamepadButton button) const {
            auto btn = button.toRaylib;
            return 1 + cast(int) iota(0, 4).countUntil!(a => IsGamepadButtonPressed(a, btn));
        }

        int isReleased(GluiGamepadButton button) const {
            auto btn = button.toRaylib;
            return 1 + cast(int) iota(0, 4).countUntil!(a => IsGamepadButtonReleased(a, btn));
        }

        int isDown(GluiGamepadButton button) const {
            auto btn = button.toRaylib;
            return 1 + cast(int) iota(0, 4).countUntil!(a => IsGamepadButtonDown(a, btn));
        }

        int isUp(GluiGamepadButton button) const {
            auto btn = button.toRaylib;
            return 1 + cast(int) iota(0, 4).countUntil!(a => IsGamepadButtonUp(a, btn));
        }

        int isRepeated(GluiGamepadButton button) const
            => 0;

    }

    private bool isScrollPressed(GluiMouseButton btn) const @trusted {

        const wheelMove = GetMouseWheelMoveV;

        switch (btn) {
            case btn.scrollUp:    return wheelMove.y > 0;
            case btn.scrollDown:  return wheelMove.y < 0;
            case btn.scrollLeft:  return wheelMove.x > 0;
            case btn.scrollRight: return wheelMove.x < 0;
            default:              assert(false);
        }

    }

    Vector2 mousePosition(Vector2 position) @trusted {

        auto positionRay = toRaylibCoords(position);
        SetMousePosition(cast(int) positionRay.x, cast(int) positionRay.y);
        return position;

    }

    Vector2 mousePosition() const @trusted {

        return toGluiCoords(GetMousePosition);

    }

    float deltaTime() const @trusted {

        return GetFrameTime;

    }

    bool hasJustResized() const @trusted {

        // TODO detect and react to DPI changes
        return IsWindowResized;

    }

    Vector2 windowSize(Vector2 size) @trusted {

        auto sizeRay = toRaylibCoords(size);
        SetWindowSize(cast(int) sizeRay.x, cast(int) sizeRay.y);
        return size;

    }

    Vector2 windowSize() const @trusted {

        return toGluiCoords(GetScreenWidth, GetScreenHeight);

    }

    float scale() const {

        return _scale;

    }

    float scale(float value) {

        return _scale = value;

    }

    Vector2 dpi() const @trusted {

        static Vector2 value;

        if (value == value.init) {

            value = GetWindowScaleDPI;
            value.x *= 96;
            value.y *= 96;

        }

        return value * _scale;

    }

    Vector2 toRaylibCoords(Vector2 position) const @trusted {

        return Vector2(position.x * hidpiScale.x, position.y * hidpiScale.y);

    }

    Rectangle toRaylibCoords(Rectangle rec) const @trusted {

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

        auto rectRay = toRaylibCoords(rect);

        BeginScissorMode(
            cast(int) rectRay.x,
            cast(int) rectRay.y,
            cast(int) rectRay.width,
            cast(int) rectRay.height,
        );

        return drawArea = rect;

    }

    Rectangle area() const {

        if (drawArea is drawArea.init)
            return Rectangle(0, 0, windowSize.tupleof);
        else
            return drawArea;

    }

    void restoreArea() @trusted {

        EndScissorMode();
        drawArea = drawArea.init;

    }

    GluiMouseCursor mouseCursor(GluiMouseCursor cursor) @trusted {

        // Hide the cursor if requested
        if (cursor.system == cursor.system.none) {
            HideCursor();
        }

        // Show the cursor
        else {
            SetMouseCursor(cursor.system.toRaylib);
            ShowCursor();
        }
        return lastMouseCursor = cursor;

    }

    GluiMouseCursor mouseCursor() const {

        return lastMouseCursor;

    }

    TextureReaper* reaper() return scope {

        return &_reaper;

    }

    glui.backend.Texture loadTexture(glui.backend.Image image) @system {

        return fromRaylib(LoadTextureFromImage(image.toRaylib));

    }

    glui.backend.Texture loadTexture(string filename) @system {

        import std.string;

        return fromRaylib(LoadTexture(filename.toStringz));

    }

    glui.backend.Texture fromRaylib(raylib.Texture texture) {

        glui.backend.Texture result;
        result.id = texture.id;
        result.tombstone = reaper.makeTombstone(this, result.id);
        result.width = texture.width;
        result.height = texture.height;
        return result;

    }

    /// Destroy a texture
    void unloadTexture(uint id) @system {

        if (!__ctfe && IsWindowReady && id != 0) {

            rlUnloadTexture(id);

        }

    }

    void drawLine(Vector2 start, Vector2 end, Color color) @trusted {

        DrawLineV(toRaylibCoords(start), toRaylibCoords(end), color);

    }

    void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) @trusted {

        DrawTriangle(toRaylibCoords(a), toRaylibCoords(b), toRaylibCoords(c), color);

    }

    void drawRectangle(Rectangle rectangle, Color color) @trusted {

        DrawRectangleRec(toRaylibCoords(rectangle), color);

    }

    void drawTexture(glui.backend.Texture texture, Rectangle rectangle, Color tint, string alt = "")
    in (false)
    do {

        // TODO filtering?
        drawTexture(texture, rectangle, tint, alt, true);

    }

    void drawTextureAlign(glui.backend.Texture texture, Rectangle rectangle, Color tint, string alt = "")
    in (false)
    do {

        drawTexture(texture, rectangle, tint, alt, true);

    }

    protected @trusted
    void drawTexture(glui.backend.Texture texture, Rectangle destination, Color tint, string alt, bool alignPixels)
    do {

        import std.math;

        destination = toRaylibCoords(destination);

        // Align texture to pixel boundaries
        if (alignPixels) {
            destination.x = floor(destination.x);
            destination.y = floor(destination.y);
        }

        const dpi = this.dpi;
        const source = Rectangle(0, 0, texture.width, texture.height);

        DrawTexturePro(texture.toRaylib, source, destination, Vector2(0, 0), 0, tint);

    }

}

/// Get the Raylib enum for a mouse cursor.
raylib.MouseCursor toRaylib(GluiMouseCursor.SystemCursors cursor) {

    with (raylib.MouseCursor)
    with (GluiMouseCursor.SystemCursors)
    switch (cursor) {

        default:
        case none:
        case systemDefault:
            return MOUSE_CURSOR_DEFAULT;

        case pointer:
            return MOUSE_CURSOR_POINTING_HAND;

        case crosshair:
            return MOUSE_CURSOR_CROSSHAIR;

        case text:
            return MOUSE_CURSOR_IBEAM;

        case allScroll:
            return MOUSE_CURSOR_RESIZE_ALL;

        case resizeEW:
            return MOUSE_CURSOR_RESIZE_EW;

        case resizeNS:
            return MOUSE_CURSOR_RESIZE_NS;

        case resizeNESW:
            return MOUSE_CURSOR_RESIZE_NESW;

        case resizeNWSE:
            return MOUSE_CURSOR_RESIZE_NWSE;

        case notAllowed:
            return MOUSE_CURSOR_NOT_ALLOWED;

    }

}

/// Get the Raylib enum for a keyboard key.
raylib.KeyboardKey toRaylib(GluiKeyboardKey key) {

    return cast(raylib.KeyboardKey) key;

}

/// Get the Raylib enum for a mouse button.
raylib.MouseButton toRaylib(GluiMouseButton button) {

    with (raylib.MouseButton)
    with (GluiMouseButton)
    final switch (button) {
        case scrollLeft:
        case scrollRight:
        case scrollUp:
        case scrollDown:
        case none:    assert(false);
        case left:    return MOUSE_BUTTON_LEFT;
        case right:   return MOUSE_BUTTON_RIGHT;
        case middle:  return MOUSE_BUTTON_MIDDLE;
        case extra1:  return MOUSE_BUTTON_SIDE;
        case extra2:  return MOUSE_BUTTON_EXTRA;
        case forward: return MOUSE_BUTTON_FORWARD;
        case back:    return MOUSE_BUTTON_BACK;
    }

}

/// Get the Raylib enum for a keyboard key.
raylib.GamepadButton toRaylib(GluiGamepadButton button) {

    return cast(raylib.GamepadButton) button;

}

/// Convert image to a Raylib image. Do not call `UnloadImage` on the result.
raylib.Image toRaylib(glui.backend.Image image) @trusted {

    raylib.Image result;
    result.data = cast(void*) image.pixels.ptr;
    result.width = image.width;
    result.height = image.height;
    result.format = PixelFormat.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
    result.mipmaps = 1;

    return result;

}

/// Convert a Glui texture to a Raylib texture.
raylib.Texture toRaylib(glui.backend.Texture texture) @trusted {

    raylib.Texture result;
    result.id = texture.id;
    result.width = texture.width;
    result.height = texture.height;
    result.format = PixelFormat.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
    result.mipmaps = 1;

    return result;

}
