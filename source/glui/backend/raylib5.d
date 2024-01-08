module glui.backend.raylib5;

version (Have_raylib_d):

debug (Glui_BuildMessages) {
    pragma(msg, "Glui: Building with Raylib 5 support");
}

import raylib;

import glui.backend;

public import raylib : Vector2, Rectangle, Color;


@safe:


class Raylib5Backend : GluiBackend {

    private {

        GluiMouseCursor lastMouseCursor;
        Rectangle drawArea;

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

        bool isPressed(int controller, GluiGamepadButton button) const
            => IsGamepadButtonPressed(controller, button.toRaylib);
        bool isReleased(int controller, GluiGamepadButton button) const
            => IsGamepadButtonReleased(controller, button.toRaylib);
        bool isDown(int controller, GluiGamepadButton button) const
            => IsGamepadButtonDown(controller, button.toRaylib);
        bool isUp(int controller, GluiGamepadButton button) const
            => IsGamepadButtonUp(controller, button.toRaylib);

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

        SetMousePosition(cast(int) position.x, cast(int) position.y);
        return position;

    }

    Vector2 mousePosition() const @trusted {

        return GetMousePosition;

    }

    float deltaTime() const @trusted {

        return GetFrameTime;

    }

    bool hasJustResized() const @trusted {

        return IsWindowResized;

    }

    Vector2 windowSize(Vector2 size) @trusted {

        SetWindowSize(cast(int) size.x, cast(int) size.y);
        return size;

    }

    Vector2 windowSize() const @trusted {

        return Vector2(GetScreenWidth, GetScreenHeight);

    }

    Vector2 hidpiScale() const @trusted {

        return GetWindowScaleDPI();

    }

    Rectangle area(Rectangle rect) @trusted {

        BeginScissorMode(
            cast(int) rect.x,
            cast(int) rect.y,
            cast(int) rect.width,
            cast(int) rect.height,
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

    glui.backend.Texture loadTexture(glui.backend.Image image) @system {

        return fromRaylib(LoadTextureFromImage(image.toRaylib));

    }

    glui.backend.Texture loadTexture(string filename) @system {

        import std.string;

        return fromRaylib(LoadTexture(filename.toStringz));

    }

    glui.backend.Texture fromRaylib(raylib.Texture texture) {

        glui.backend.Texture result;
        result.backend = this;
        result.id = texture.id;
        result.width = texture.width;
        result.height = texture.height;
        return result;

    }

    /// Destroy a texture
    void unloadTexture(glui.backend.Texture texture) @system {

        if (!__ctfe && IsWindowReady && texture.id != 0) {

            UnloadTexture(texture.toRaylib);

        }

    }

    void drawLine(Vector2 start, Vector2 end, Color color) @trusted {

        DrawLineV(start, end, color);

    }

    void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) @trusted {

        DrawTriangle(a, b, c, color);

    }

    void drawRectangle(Rectangle rectangle, Color color) @trusted {

        DrawRectangleRec(rectangle, color);

    }

    void drawTexture(glui.backend.Texture texture, Vector2 position, Color tint) @trusted
    in (false)
    do {

        DrawTextureV(texture.toRaylib, position, tint);

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
