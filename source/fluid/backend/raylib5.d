module fluid.backend.raylib5;

version (Have_raylib_d):

debug (Fluid_BuildMessages) {
    pragma(msg, "Fluid: Building with Raylib 5 support");
}

import raylib;

import std.range;
import std.string;
import std.algorithm;

import fluid.backend;
import fluid.backend : MouseButton, KeyboardKey, GamepadButton;

public import raylib : Vector2, Rectangle, Color;


@safe:


// Coordinate scaling will translate Fluid coordinates, where each pixels is 1/96th of an inch, to screen coordinates,
// making use of DPI information provided by the system. This flag is only set on macOS, where the system handles this
// automatically.
version (OSX)
    version = Fluid_DisableScaling;

class Raylib5Backend : FluidBackend {

    private {

        TextureReaper _reaper;
        FluidMouseCursor lastMouseCursor;
        Rectangle drawArea;
        Color _tint = color!"fff";
        float _scale = 1;
        Shader _alphaImageShader;
        Shader _palettedAlphaImageShader;
        int _palettedAlphaImageShader_palette;
        fluid.backend.Texture _paletteTexture;
        int[uint] _mipmapCount;

    }

    /// Shader code for alpha images.
    enum alphaImageShaderCode = q{
        #version 330
        in vec2 fragTexCoord;
        in vec4 fragColor;
        out vec4 finalColor;
        uniform sampler2D texture0;
        uniform vec4 colDiffuse;
        void main() {
            // Alpha masks are white to make them practical for modulation
            vec4 texelColor = texture(texture0, fragTexCoord);
            finalColor = vec4(1, 1, 1, texelColor.r) * colDiffuse * fragColor;
        }
    };

    /// Shader code for palette iamges.
    enum palettedAlphaImageShaderCode = q{
        #version 330
        in vec2 fragTexCoord;
        in vec4 fragColor;
        out vec4 finalColor;
        uniform sampler2D texture0;
        uniform sampler2D palette;
        uniform vec4 colDiffuse;
        void main() {
            // index.r is alpha/opacity
            // index.a is palette index
            vec4 index = texture(texture0, fragTexCoord);
            vec4 texel = texture(palette, vec2(index.a, 0));
            finalColor = texel * vec4(1, 1, 1, index.r) * colDiffuse * fragColor;
        }
    };

    @trusted {

        bool isPressed(MouseButton button) const
            => IsMouseButtonPressed(button.toRaylib);
        bool isReleased(MouseButton button) const
            => IsMouseButtonReleased(button.toRaylib);
        bool isDown(MouseButton button) const
            => IsMouseButtonDown(button.toRaylib);
        bool isUp(MouseButton button) const
            => IsMouseButtonUp(button.toRaylib);

        bool isPressed(KeyboardKey key) const => IsKeyPressed(key.toRaylib);
        bool isReleased(KeyboardKey key) const => IsKeyReleased(key.toRaylib);
        bool isDown(KeyboardKey key) const => IsKeyDown(key.toRaylib);
        bool isUp(KeyboardKey key) const => IsKeyUp(key.toRaylib);
        bool isRepeated(KeyboardKey key) const => IsKeyPressedRepeat(key.toRaylib);

        dchar inputCharacter() => cast(dchar) GetCharPressed();

        int isPressed(GamepadButton button) const {
            auto btn = button.toRaylib;
            return 1 + cast(int) iota(0, 4).countUntil!(a => IsGamepadButtonPressed(a, btn));
        }

        int isReleased(GamepadButton button) const {
            auto btn = button.toRaylib;
            return 1 + cast(int) iota(0, 4).countUntil!(a => IsGamepadButtonReleased(a, btn));
        }

        int isDown(GamepadButton button) const {
            auto btn = button.toRaylib;
            return 1 + cast(int) iota(0, 4).countUntil!(a => IsGamepadButtonDown(a, btn));
        }

        int isUp(GamepadButton button) const {
            auto btn = button.toRaylib;
            return 1 + cast(int) iota(0, 4).countUntil!(a => IsGamepadButtonUp(a, btn));
        }

        int isRepeated(GamepadButton button) const {
            return 0;
        }

    }

    ~this() @trusted {

        if (IsWindowReady()) {

            UnloadShader(_alphaImageShader);
            UnloadShader(_palettedAlphaImageShader);
            _paletteTexture.destroy();

        }

    }

    /// Get shader for images with the `alpha` format.
    raylib.Shader alphaImageShader() @trusted {

        // Shader created and available for use
        if (IsShaderReady(_alphaImageShader))
            return _alphaImageShader;

        // Create the shader
        return _alphaImageShader = LoadShaderFromMemory(null, alphaImageShaderCode.ptr);

    }

    /// Get shader for images with the `palettedAlpha` format.
    /// Params:
    ///     palette = Palette to use with the shader.
    raylib.Shader palettedAlphaImageShader(Color[] palette) @trusted {

        // Load the shader
        if (!IsShaderReady(_palettedAlphaImageShader)) {

            _palettedAlphaImageShader = LoadShaderFromMemory(null, palettedAlphaImageShaderCode.ptr);
            _palettedAlphaImageShader_palette = GetShaderLocation(_palettedAlphaImageShader, "palette");

        }

        auto paletteTexture = this.paletteTexture(palette);

        // Load the palette
        SetShaderValueTexture(_palettedAlphaImageShader, _palettedAlphaImageShader_palette, paletteTexture.toRaylib);

        return _palettedAlphaImageShader;

    }

    Vector2 mousePosition(Vector2 position) @trusted {

        auto positionRay = toRaylibCoords(position);
        SetMousePosition(cast(int) positionRay.x, cast(int) positionRay.y);
        return position;

    }

    Vector2 mousePosition() const @trusted {

        return toFluidCoords(GetMousePosition);

    }

    Vector2 scroll() const @trusted {

        // Normalize the value: Linux and Windows provide trinary values (-1, 0, 1) but macOS gives analog that often
        // goes far higher than that. This is a rough guess of the proportions based on feeling.
        version (OSX)
            return -GetMouseWheelMoveV / 4;
        else
            return -GetMouseWheelMoveV;

    }

    string clipboard(string value) @trusted {

        SetClipboardText(value.toStringz);

        return value;

    }

    string clipboard() const @trusted {

        return GetClipboardText().fromStringz.dup;

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

        return toFluidCoords(GetScreenWidth, GetScreenHeight);

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

        version (Fluid_DisableScaling)
            return position;
        else
            return Vector2(position.x * hidpiScale.x, position.y * hidpiScale.y);

    }

    Rectangle toRaylibCoords(Rectangle rec) const @trusted {

        version (Fluid_DisableScaling)
            return rec;
        else
            return Rectangle(
                rec.x * hidpiScale.x,
                rec.y * hidpiScale.y,
                rec.width * hidpiScale.x,
                rec.height * hidpiScale.y,
            );

    }

    Vector2 toFluidCoords(Vector2 position) const @trusted {

        version (Fluid_DisableScaling)
            return position;
        else
            return Vector2(position.x / hidpiScale.x, position.y / hidpiScale.y);

    }

    Vector2 toFluidCoords(float x, float y) const @trusted {

        version (Fluid_DisableScaling)
            return Vector2(x, y);
        else
            return Vector2(x / hidpiScale.x, y / hidpiScale.y);

    }

    Rectangle toFluidCoords(Rectangle rec) const @trusted {

        version (Fluid_DisableScaling)
            return rec;
        else
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

    FluidMouseCursor mouseCursor(FluidMouseCursor cursor) @trusted {

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

    FluidMouseCursor mouseCursor() const {

        return lastMouseCursor;

    }

    TextureReaper* reaper() return scope {

        return &_reaper;

    }

    fluid.backend.Texture loadTexture(fluid.backend.Image image) @system {

        return fromRaylib(LoadTextureFromImage(image.toRaylib));

    }

    fluid.backend.Texture loadTexture(string filename) @system {

        import std.string;

        return fromRaylib(LoadTexture(filename.toStringz));

    }

    void updateTexture(fluid.backend.Texture texture, fluid.backend.Image image) @system
    in (false)
    do {

        UpdateTexture(texture.toRaylib, image.data.ptr);

    }

    private fluid.backend.Texture fromRaylib(raylib.Texture texture) {

        const format = cast(raylib.PixelFormat) texture.format;

        fluid.backend.Texture result;
        result.id = texture.id;
        result.format = format.fromRaylib;
        result.tombstone = reaper.makeTombstone(this, result.id);
        result.width = texture.width;
        result.height = texture.height;
        return result;

    }

    /// Destroy a texture
    void unloadTexture(uint id) @system {

        if (!__ctfe && IsWindowReady && id != 0) {

            _mipmapCount.remove(id);
            rlUnloadTexture(id);

        }

    }

    Color tint(Color color) {

        return _tint = color;

    }

    Color tint() const {

        return _tint;

    }

    void drawLine(Vector2 start, Vector2 end, Color color) @trusted {

        DrawLineV(toRaylibCoords(start), toRaylibCoords(end), multiply(color, tint));

    }

    void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) @trusted {

        DrawTriangle(toRaylibCoords(a), toRaylibCoords(b), toRaylibCoords(c), multiply(color, tint));

    }

    void drawCircle(Vector2 center, float radius, Color color) @trusted {

        DrawCircleV(center, radius, color);

    }

    void drawCircleOutline(Vector2 center, float radius, Color color) @trusted {

        DrawCircleLinesV(center, radius, color);

    }

    void drawRectangle(Rectangle rectangle, Color color) @trusted {

        DrawRectangleRec(toRaylibCoords(rectangle), multiply(color, tint));

    }

    void drawTexture(fluid.backend.Texture texture, Rectangle rectangle, Color tint)
        @trusted
    in (false)
    do {

        auto rayTexture = texture.toRaylib;

        // Ensure the texture has mipmaps, if possible, to enable trilinear filtering
        if (auto mipmapCount = texture.id in _mipmapCount) {

            rayTexture.mipmaps = *mipmapCount;

        }

        else {

            // Generate mipmaps
            GenTextureMipmaps(&rayTexture);
            _mipmapCount[texture.id] = rayTexture.mipmaps;

        }

        // Set filter accordingly
        const filter = rayTexture.mipmaps == 1
            ? TextureFilter.TEXTURE_FILTER_BILINEAR
            : TextureFilter.TEXTURE_FILTER_TRILINEAR;

        SetTextureFilter(rayTexture, filter);
        drawTexture(texture, rectangle, tint, false);

    }

    void drawTextureAlign(fluid.backend.Texture texture, Rectangle rectangle, Color tint)
        @trusted
    in (false)
    do {

        auto rayTexture = texture.toRaylib;

        SetTextureFilter(rayTexture, TextureFilter.TEXTURE_FILTER_POINT);
        drawTexture(texture, rectangle, tint, true);

    }

    protected @trusted
    void drawTexture(fluid.backend.Texture texture, Rectangle destination, Color tint, bool alignPixels)
    do {

        import std.math;

        // Align texture to pixel boundaries
        if (alignPixels) {
            destination.x = floor(destination.x * hidpiScale.x) / hidpiScale.x;
            destination.y = floor(destination.y * hidpiScale.y) / hidpiScale.y;
        }

        destination = toRaylibCoords(destination);

        const source = Rectangle(0, 0, texture.width, texture.height);
        Shader shader;

        // Enable shaders relevant to given format
        switch (texture.format) {

            case fluid.backend.Image.Format.alpha:
                shader = alphaImageShader;
                break;

            case fluid.backend.Image.Format.palettedAlpha:
                shader = palettedAlphaImageShader(texture.palette);
                break;

            default: break;

        }

        // Start shaders, if applicable
        if (IsShaderReady(shader))
            BeginShaderMode(shader);

        DrawTexturePro(texture.toRaylib, source, destination, Vector2(0, 0), 0, multiply(tint, this.tint));

        // End shaders
        if (IsShaderReady(shader))
            EndShaderMode();

    }

    /// Create a palette texture.
    private fluid.backend.Texture paletteTexture(scope Color[] colors) @trusted
    in (colors.length <= 256, "There can only be at most 256 colors in a palette.")
    do {

        // Fill empty slots in the palette with white
        Color[256] allColors = color("#fff");
        allColors[0 .. colors.length] = colors;

        // Prepare an image for the texture
        scope image = fluid.backend.Image(allColors[], 256, 1);

        // Create the texture if it doesn't exist
        if (_paletteTexture is _paletteTexture.init)
            _paletteTexture = loadTexture(image);

        // Or, update existing palette image
        else
            updateTexture(_paletteTexture, image);

        return _paletteTexture;

    }

}

/// Get the Raylib enum for a mouse cursor.
raylib.MouseCursor toRaylib(FluidMouseCursor.SystemCursors cursor) {

    with (raylib.MouseCursor)
    with (FluidMouseCursor.SystemCursors)
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
raylib.KeyboardKey toRaylib(KeyboardKey key) {

    return cast(raylib.KeyboardKey) key;

}

/// Get the Raylib enum for a mouse button.
raylib.MouseButton toRaylib(MouseButton button) {

    with (raylib.MouseButton)
    with (MouseButton)
    final switch (button) {
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
raylib.GamepadButton toRaylib(GamepadButton button) {

    return cast(raylib.GamepadButton) button;

}

/// Convert image to a Raylib image. Do not call `UnloadImage` on the result.
raylib.Image toRaylib(fluid.backend.Image image) @trusted {

    raylib.Image result;
    result.data = image.data.ptr;
    result.width = image.width;
    result.height = image.height;
    result.format = image.format.toRaylib;
    result.mipmaps = 1;
    return result;

}

/// Convert Fluid image format to Raylib's closest alternative.
raylib.PixelFormat toRaylib(fluid.backend.Image.Format imageFormat) {

    final switch (imageFormat) {

        case imageFormat.rgba:
            return PixelFormat.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;

        case imageFormat.palettedAlpha:
            return PixelFormat.PIXELFORMAT_UNCOMPRESSED_GRAY_ALPHA;

        case imageFormat.alpha:
            return PixelFormat.PIXELFORMAT_UNCOMPRESSED_GRAYSCALE;

    }

}

fluid.backend.Image.Format fromRaylib(raylib.PixelFormat pixelFormat) {

    switch (pixelFormat) {

        case pixelFormat.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8:
            return fluid.backend.Image.Format.rgba;

        case pixelFormat.PIXELFORMAT_UNCOMPRESSED_GRAY_ALPHA:
            return fluid.backend.Image.Format.palettedAlpha;

        case pixelFormat.PIXELFORMAT_UNCOMPRESSED_GRAYSCALE:
            return fluid.backend.Image.Format.alpha;

        default: assert(false, "Unrecognized format");

    }

}

/// Convert a fluid texture to a Raylib texture.
raylib.Texture toRaylib(fluid.backend.Texture texture) @trusted {

    raylib.Texture result;
    result.id = texture.id;
    result.width = texture.width;
    result.height = texture.height;
    result.format = texture.format.toRaylib;
    result.mipmaps = 1;

    return result;

}
