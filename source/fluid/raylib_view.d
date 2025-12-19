/// Raylib connection layer for Fluid. This makes it possible to render Fluid apps and user interfaces through Raylib.
///
/// Use `raylibStack` for a complete implementation, and `raylibView` for a minimal one. The complete stack
/// is recommended for most usages, as it bundles full mouse and keyboard support, while the chain node may
/// be preferred for advanced usage and requires manual setup. See `RaylibView`'s documentation for more
/// information.
///
/// Note that because Raylib introduces breaking changes in every version, the current version of Raylib should
/// be specified using `raylibStack.v5_5()`. Raylib 5.5 is currently the oldest version supported,
/// and is the default in case no version is chosen explicitly.
module fluid.raylib_view;

version (Have_raylib_d):

debug (Fluid_BuildMessages) {
    pragma(msg, "Fluid: Building with Raylib 5.5 support (RaylibView)");
}

// Coordinate scaling will translate Fluid coordinates, where each pixels is 1/96th of an inch, to screen coordinates,
// making use of DPI information provided by the system. This flag is only set on macOS, where the system handles this
// automatically.
version (OSX) {
    version = Fluid_DisableScaling;

    debug (Fluid_BuildMessages) {
        pragma(msg, "Fluid: Disabling coordinate scaling on macOS");
    }
}

import raylib;
import optional;

import std.meta;
import std.traits;
import std.array;
import std.string;

import fluid.node;
import fluid.utils;
import fluid.types;
import fluid.style : Cursor;
import fluid.node_chain;

import fluid.future.arena;
import fluid.future.context;

import fluid.io.time;
import fluid.io.canvas;
import fluid.io.hover;
import fluid.io.mouse;
import fluid.io.focus;
import fluid.io.keyboard;
import fluid.io.clipboard;
import fluid.io.image_load;
import fluid.io.preference;
import fluid.io.overlay;

static if (!__traits(compiles, IsShaderReady))
    private alias IsShaderReady = IsShaderValid;

@safe:

/// `raylibStack` implements all I/O functionality needed for Fluid to function, using Raylib to read user input
/// and present visuals on the screen.
///
/// Specify Raylib version by using a member: `raylibStack.v5_5()` will create a stack for Raylib 5.5.
///
/// `raylibStack` provides a default implementation for `TimeIO`, `PreferenceIO`,  `HoverIO`, `FocusIO`, `ActionIO`
/// and `FileIO`, on top of all the systems provided by Raylib itself: `CanvasIO`, `KeyboardIO`, `MouseIO`,
/// `ClipboardIO` and `ImageLoadIO`.
enum raylibStack = RaylibViewBuilder!RaylibStack.init;

/// `raylibView` implements some I/O functionality using the Raylib library, namely `CanvasIO`, `KeyboardIO`,
/// `MouseIO`, `ClipboardIO` and `ImageLoadIO`.
///
/// These systems are not enough for Fluid to function. Use `raylibStack` to also initialize all other necessary
/// systems.
///
/// Specify Raylib version by using a member: `raylibView.v5_5()` will create a stack for Raylib 5.5.
enum raylibView = RaylibViewBuilder!RaylibView.init;

/// Use this enum to pick version of Raylib to use.
enum RaylibViewVersion {
    v5_5,
}

/// Wrapper over `NodeBuilder` which enables specifying Raylib version.
struct RaylibViewBuilder(alias T) {

    alias v5_5 this;
    enum v5_5 = nodeBuilder!(T!(RaylibViewVersion.v5_5));

}

/// Implements Raylib support through Fluid's I/O system. Use `raylibStack` or `raylibView` to construct.
///
/// `RaylibView` relies on a number of I/O systems that it does not implement, but must be provided for it
/// to function. Use `RaylibStack` to initialize the chain along with default choices for these systems,
/// suitable for most uses, or provide these systems as parent nodes:
///
/// * `HoverIO` for mouse support. Fluid does not presently support mobile devices through Raylib, and Raylib's
///   desktop version does not fully support touchscreens (as GLFW does not).
/// * `FocusIO` for keyboard and gamepad support. Gamepad support may currently be limited.
/// * `TimeIO` for measuring time between mouse clicks.
/// * `PreferenceIO` for user preferences from the system.
///
/// There is a few systems that `RaylibView` does not require, but are included in `RaylibStack` to support
/// commonly needed functionality:
///
/// * `ActionIO` for translating user input into a format Fluid nodes can understand.
/// * `FileIO` for loading and writing files.
///
/// `RaylibView` itself provides a number of I/O systems using functionality from the Raylib library:
///
/// * `CanvasIO` for drawing nodes and providing visual output.
/// * `MouseIO` to provide mouse support.
/// * `KeyboardIO` to provide keyboard support.
/// * `ClipboardIO` to access system keyboard.
/// * `ImageLoadIO` to load images using codecs available in Raylib.
class RaylibView(RaylibViewVersion raylibVersion) : Node, CanvasIO, MouseIO, KeyboardIO, ClipboardIO, ImageLoadIO {

    HoverIO hoverIO;
    FocusIO focusIO;
    TimeIO timeIO;
    PreferenceIO preferenceIO;

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

    /// Shader code for palette images.
    enum palettedAlphaImageShaderCode = q{
        #version 330
        in vec2 fragTexCoord;
        in vec4 fragColor;
        out vec4 finalColor;
        uniform sampler2D texture0;
        uniform sampler2D palette;
        uniform vec4 colDiffuse;
        void main() {
            // index.a is alpha/opacity
            // index.r is palette index
            vec4 index = texture(texture0, fragTexCoord);
            vec4 texel = texture(palette, vec2(index.r, 0));
            finalColor = texel * vec4(1, 1, 1, index.a) * colDiffuse * fragColor;
        }
    };

    public {

        /// Node drawn by this view.
        Node next;

        /// Scale set for this view. It can be controlled through the `FLUID_SCALE` environment
        /// variable (expected to be a float, e.g. `1.5` or a pair of floats `1.5x1.25`)
        ///
        /// Changing the scale requires an `updateSize` call.
        auto scale = Vector2(1, 1);

    }

    private struct RaylibImage {
        fluid.Image image;
        raylib.Texture texture;
    }

    private {

        // Window state
        Vector2 _dpi;
        Vector2 _dpiScale;
        Vector2 _windowSize;
        Rectangle _cropArea;

        // Resources
        ResourceArena!RaylibImage _images;
        raylib.Texture _paletteTexture;
        Shader _alphaImageShader;
        Shader _palettedAlphaImageShader;
        int _palettedAlphaImageShader_palette;

        /// Map of image pointers (image.data.ptr) to indices in the resource arena (_images)
        int[size_t] _imageIndices;

        // I/O
        HoverPointer _mousePointer;
        Appender!(KeyboardKey[]) _heldKeys;
        MultipleClickSensor _multiClickSensor;

    }

    this(Node next = null) {

        this.next = next;
        this.scale = getGlobalScale();

        // Initialize the mouse
        _mousePointer.device = this;
        _mousePointer.number = 0;

    }

    override void resizeImpl(Vector2) @trusted {

        require(focusIO);
        require(hoverIO);
        require(timeIO);
        require(preferenceIO);
        hoverIO.loadTo(_mousePointer);

        // Fetch data from Raylib
        _dpiScale = GetWindowScaleDPI;
        _dpi = Vector2(_dpiScale.x * scale.x * 96, _dpiScale.y * scale.y * 96);
        _windowSize = toFluid(GetScreenWidth, GetScreenHeight);
        resetCropArea();

        // Load shaders
        if (!IsShaderReady(_alphaImageShader)) {
            _alphaImageShader = LoadShaderFromMemory(null, alphaImageShaderCode.ptr);
        }
        if (!IsShaderReady(_palettedAlphaImageShader)) {
            _palettedAlphaImageShader = LoadShaderFromMemory(null, palettedAlphaImageShaderCode.ptr);
            _palettedAlphaImageShader_palette = GetShaderLocation(_palettedAlphaImageShader, "palette");
        }

        // Free resources
        _images.startCycle((newIndex, ref resource) @trusted {

            const id = cast(size_t) resource.image.data.ptr;

            // Resource freed
            if (newIndex == -1) {
                _imageIndices.remove(id);
                UnloadTexture(resource.texture);
            }

            // Moved
            else {
                _imageIndices[id] = newIndex;
            }

        });

        // Enable the system
        auto io = this.implementIO();

        // Resize the node
        if (next) {
            resizeChild(next, _windowSize);
        }

        // RaylibView does not take space in whatever it is placed in
        minSize = Vector2();

    }

    override void drawImpl(Rectangle, Rectangle) @trusted {

        updateMouse();
        updateKeyboard();

        if (next) {
            resetCropArea();
            drawChild(next, _cropArea);
        }

        if (IsWindowResized) {
            updateSize();
        }

    }

    protected void updateMouse() @trusted {

        // Update mouse status
        _mousePointer.position     = toFluid(GetMousePosition);
        _mousePointer.scroll       = scroll();
        _mousePointer.isScrollHeld = false;
        _mousePointer.clickCount   = 0;

        // Detect multiple mouse clicks
        if (IsMouseButtonDown(MouseButton.MOUSE_BUTTON_LEFT)) {
            _multiClickSensor.hold(timeIO, preferenceIO, _mousePointer);
            _mousePointer.clickCount   = _multiClickSensor.clicks;
        }
        else if (IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT)) {
            _multiClickSensor.activate();
            _mousePointer.clickCount   = _multiClickSensor.clicks;
        }

        hoverIO.loadTo(_mousePointer);

        // Set cursor icon
        if (auto node = cast(Node) hoverIO.hoverOf(_mousePointer)) {

            const cursor = node.pickStyle().mouseCursor;

            // Hide the cursor if requested
            if (cursor.system == cursor.system.none) {
                HideCursor();
            }
            // Show the cursor
            else {
                SetMouseCursor(cursor.system.toRaylib);
                ShowCursor();
            }

        }
        else {
            SetMouseCursor(Cursor.systemDefault.system.toRaylib);
            ShowCursor();
        }

        // Send buttons
        foreach (button; NoDuplicates!(EnumMembers!(MouseIO.Button))) {

            const buttonRay = button.toRaylib;

            if (buttonRay == -1) continue;

            // Active event
            if (IsMouseButtonReleased(buttonRay)) {
                hoverIO.emitEvent(_mousePointer, MouseIO.createEvent(button, true));
            }

            else if (IsMouseButtonDown(buttonRay)) {
                hoverIO.emitEvent(_mousePointer, MouseIO.createEvent(button, false));
            }

        }

    }

    protected void updateKeyboard() @trusted {

        import std.utf;

        // Take text input character by character
        while (true) {

            // TODO take more at once
            char[4] buffer;

            const ch = cast(dchar) GetCharPressed();
            if (ch == 0) break;

            const size = buffer.encode(ch);
            focusIO.typeText(buffer[0 .. size]);

        }

        // Find all newly pressed keyboard keys
        while (true) {

            const keyRay = cast(KeyboardKey) GetKeyPressed();
            if (keyRay == 0) break;

            _heldKeys ~= keyRay;

        }

        size_t newIndex;
        foreach (keyRay; _heldKeys[]) {

            const key = keyRay.toFluid;

            // Pressed
            if (IsKeyPressed(keyRay) || IsKeyPressedRepeat(keyRay)) {
                focusIO.emitEvent(KeyboardIO.createEvent(key, true));
                _heldKeys[][newIndex++] = keyRay;
            }

            // Held
            else if (IsKeyDown(keyRay)) {
                focusIO.emitEvent(KeyboardIO.createEvent(key, false));
                _heldKeys[][newIndex++] = keyRay;
            }

        }
        _heldKeys.shrinkTo(newIndex);

    }

    /// Returns:
    ///     Distance travelled by the mouse in Fluid coordinates.
    private Vector2 scroll() @trusted {

        const move = -GetMouseWheelMoveV;
        const speed = preferenceIO.scrollSpeed;

        return Vector2(move.x * speed.x, move.y * speed.y);

    }

    override Vector2 dpi() const nothrow {
        return _dpi;
    }

    override Optional!Rectangle cropArea() const nothrow {
        return typeof(return)(_cropArea);
    }

    override void cropArea(Rectangle area) nothrow @trusted {
        _cropArea = area;
        const rectRay = toRaylib(area);
        BeginScissorMode(
            cast(int) rectRay.x,
            cast(int) rectRay.y,
            cast(int) rectRay.width,
            cast(int) rectRay.height,
        );
    }

    override void resetCropArea() nothrow {
        cropArea(Rectangle(0, 0, _windowSize.tupleof));
    }

    /// Convert position of a point or rectangle in Fluid space to Raylib space.
    /// Params:
    ///     position = Fluid position, where each coordinate is specified in pixels (1/96th of an inch).
    ///     rectangle = Rectangle in Fluid space.
    /// Returns:
    ///     Raylib position or rectangle, where each coordinate is specified in screen dots.
    Vector2 toRaylib(Vector2 position) const nothrow {

        version (Fluid_DisableScaling)
            return position;
        else
            return toDots(position);

    }

    /// ditto
    Rectangle toRaylib(Rectangle rectangle) const nothrow {

        version (Fluid_DisableScaling)
            return rectangle;
        else
            return Rectangle(
                toDots(rectangle.start).tupleof,
                toDots(rectangle.size).tupleof,
            );

    }

    /// Convert position of a point or rectangle in Raylib space to Fluid space.
    /// Params:
    ///     position = Raylib position, where each coordinate is specified in screen dots.
    ///     rectangle = Rectangle in Raylib space.
    /// Returns:
    ///     Position in Fluid space
    Vector2 toFluid(Vector2 position) const nothrow {

        version (Fluid_DisableScaling)
            return position;
        else
            return fromDots(position);

    }

    /// ditto
    Vector2 toFluid(float x, float y) const nothrow {

        version (Fluid_DisableScaling)
            return Vector2(x, y);
        else
            return fromDots(Vector2(x, y));

    }

    /// ditto
    Rectangle toFluid(Rectangle rectangle) const nothrow {

        version (Fluid_DisableScaling)
            return rectangle;
        else
            return Rectangle(
                fromDots(rectangle.start).tupleof,
                fromDots(rectangle.size).tupleof,
            );

    }

    /// Get a Raylib texture for the corresponding drawable image. The image MUST be loaded.
    raylib.Texture textureFor(DrawableImage image) nothrow @trusted {
        return _images[image.id].texture;
    }

    /// Get the shader used for `alpha` images. This shader is loaded on the first resize,
    /// and is not accessible before.
    /// Returns:
    ///     Shader used for images with the `alpha` format set.
    Shader alphaImageShader() nothrow @trusted {
        assert(IsShaderReady(_alphaImageShader), "alphaImageShader is not accessible before resize");
        return _alphaImageShader;
    }

    /// Get the shader used for `palettedAlpha` images. This shader is loaded on the first resize,
    /// and is not accessible before.
    /// Params:
    ///     palette = Palette to use with the shader.
    /// Returns:
    ///     Shader used for images with the `palettedAlpha` format set.
    Shader palettedAlphaImageShader(Color[] palette) nothrow @trusted {
        assert(IsShaderReady(_palettedAlphaImageShader), "palettedAlphaImageShader is not accessible before resize");

        auto paletteTexture = this.paletteTexture(palette);

        // Load the palette
        SetShaderValueTexture(_palettedAlphaImageShader, _palettedAlphaImageShader_palette, paletteTexture);

        return _palettedAlphaImageShader;
    }

    /// Create a palette texture.
    private raylib.Texture paletteTexture(scope Color[] colors) nothrow @trusted
    in (colors.length <= 256, "There can only be at most 256 colors in a palette.")
    do {

        // Fill empty slots in the palette with white
        Color[256] allColors = Color(0xff, 0xff, 0xff, 0xff);
        allColors[0 .. colors.length] = colors;

        // Prepare an image for the texture
        scope image = fluid.Image(allColors[], 256, 1);

        // Create the texture if it doesn't exist
        if (_paletteTexture is _paletteTexture.init)
            _paletteTexture = LoadTextureFromImage(image.toRaylib);

        // Or, update existing palette image
        else
            UpdateTexture(_paletteTexture, image.data.ptr);

        return _paletteTexture;

    }

    override void drawTriangleImpl(Vector2 a, Vector2 b, Vector2 c, Color color) nothrow @trusted {
        DrawTriangle(
            toRaylib(a),
            toRaylib(b),
            toRaylib(c),
            color);
    }

    override void drawCircleImpl(Vector2 center, float radius, Color color) nothrow @trusted {
        const centerRay = toRaylib(center);
        const radiusRay = toRaylib(Vector2(radius, radius));
        DrawEllipse(
            cast(int) centerRay.x,
            cast(int) centerRay.y,
            radiusRay.tupleof,
            color);
    }

    override void drawCircleOutlineImpl(Vector2 center, float radius, float width, Color color) nothrow @trusted {
        const centerRay = toRaylib(center);
        const radiusRay = toRaylib(Vector2(radius, radius));
        const previousLineWidth = rlGetLineWidth();
        // Note: This isn't very accurate at greater widths
        rlSetLineWidth(width);
        DrawEllipseLines(
            cast(int) centerRay.x,
            cast(int) centerRay.y,
            radiusRay.tupleof,
            color);
        rlDrawRenderBatchActive();
        rlSetLineWidth(previousLineWidth);
    }

    override void drawRectangleImpl(Rectangle rectangle, Color color) nothrow @trusted {
        DrawRectangleRec(
            toRaylib(rectangle),
            color);
    }

    override void drawLineImpl(Vector2 start, Vector2 end, float width, Color color) nothrow @trusted {
        DrawLineEx(
            toRaylib(start),
            toRaylib(end),
            width,
            color);
    }

    override void drawImageImpl(DrawableImage image, Rectangle destination, Color tint) nothrow {
        drawImageImpl(image, destination, tint, false);
    }

    override void drawHintedImageImpl(DrawableImage image, Rectangle destination, Color tint) nothrow {
        drawImageImpl(image, destination, tint, true);
    }

    private void drawImageImpl(DrawableImage image, Rectangle destination, Color tint, bool hinted) nothrow @trusted {

        import std.math;

        // Perform hinting if enabled
        auto start = destination.start;
        if (hinted) {
            start = toDots(destination.start);
            start.x = floor(start.x);
            start.y = floor(start.y);
            start = fromDots(start);
        }

        const destinationRay = Rectangle(
            toRaylib(start).tupleof,
            toRaylib(destination.size).tupleof
        );

        const source = Rectangle(0, 0, image.width, image.height);
        Shader shader;

        // Enable shaders relevant to given format
        switch (image.format) {

            case fluid.Image.Format.alpha:
                shader = alphaImageShader;
                break;

            case fluid.Image.Format.palettedAlpha:
                shader = palettedAlphaImageShader(image.palette);
                break;

            default: break;

        }

        // Start shaders, if applicable
        if (IsShaderReady(shader))
            BeginShaderMode(shader);

        auto texture = textureFor(image);

        DrawTexturePro(texture, source, destinationRay, Vector2(0, 0), 0, tint);

        // End shaders
        if (IsShaderReady(shader))
            EndShaderMode();

    }

    override int load(fluid.Image image) nothrow @trusted {

        const empty = image.width * image.height == 0;
        const id = empty
            ? 0
            : cast(size_t) image.data.ptr;

        // Image already loaded, reuse
        if (auto indexPtr = id in _imageIndices) {

            auto resource = _images[*indexPtr];

            // Image was updated, mirror the changes
            if (image.revisionNumber > resource.image.revisionNumber) {

                const sameFormat = resource.image.width == image.width
                    && resource.image.height == image.height
                    && resource.image.format == image.format;

                resource.image = image;

                if (empty) { }

                // Update the texture in place if the format is the same
                if (sameFormat) {
                    UpdateTexture(resource.texture, image.data.ptr);
                }

                // Reupload the image if not
                else {
                    UnloadTexture(resource.texture);
                    resource.texture = LoadTextureFromImage(image.toRaylib);
                }

            }

            _images.reload(*indexPtr, resource);
            return *indexPtr;
        }

        // Empty image; do not upload
        else if (empty) {
            auto internalImage = RaylibImage(image, raylib.Texture.init);
            return _imageIndices[id] = _images.load(internalImage);
        }

        // Load the image
        else {
            auto texture = LoadTextureFromImage(image.toRaylib);
            auto internalImage = RaylibImage(image, texture);

            return _imageIndices[id] = _images.load(internalImage);
        }

    }

    override bool writeClipboard(string text) nothrow @trusted {

        SetClipboardText(text.toStringz);
        return true;

    }

    override char[] readClipboard(return scope char[] buffer, ref int offset) nothrow @trusted {

        import std.algorithm : min;

        // This is horrible but this API will change https://git.samerion.com/Samerion/Fluid/issues/276
        const scope clipboard = GetClipboardText().fromStringz;

        // Read the entire text, nothing remains to be read
        if (offset >= clipboard.length) return null;

        // Get remaining text
        const text = clipboard[offset .. $];
        const length = min(text.length, buffer.length);

        offset += length;
        return buffer[0 .. length] = text[0 .. length];

    }

    override fluid.Image loadImage(const ubyte[] image) @trusted {

        assert(image.length < int.max, "Image is too big to load");

        const fileType = identifyImageType(image);

        auto imageRay = LoadImageFromMemory(fileType.ptr, image.ptr, cast(int) image.length);
        return imageRay.toFluid;

    }

}

/// A complete implementation of all systems Fluid needs to function, using Raylib as the base for communicating with
/// the operating system. Use `raylibStack` to construct.
///
/// For a minimal installation that only includes systems provided by Raylib use `RaylibView`.
/// Note that `RaylibView` does not provide all the systems Fluid needs to function. See its documentation for more
/// information.
///
/// On top of systems already provided by `RaylibView`, `RaylibStack` also includes `HoverIO`, `FocusIO`, `ActionIO`,
/// `PreferenceIO`, `TimeIO` and `FileIO`. You can access them through fields named `hoverIO`, `focusIO`, `actionIO`,
/// `preferenceIO`, `timeIO` and `fileIO` respectively.
class RaylibStack(RaylibViewVersion raylibVersion) : Node, TreeWrapper {

    import fluid.hover_chain;
    import fluid.focus_chain;
    import fluid.input_map_chain;
    import fluid.preference_chain;
    import fluid.time_chain;
    import fluid.file_chain;
    import fluid.overlay_chain;

    public {

        /// I/O implementations provided by the stack.
        FocusChain focusIO;

        /// ditto
        HoverChain hoverIO;

        /// ditto
        InputMapChain actionIO;

        /// ditto
        PreferenceChain preferenceIO;

        /// ditto
        TimeChain timeIO;

        /// ditto
        FileChain fileIO;

        /// ditto
        RaylibView!raylibVersion raylibIO;

        /// ditto
        OverlayChain overlayIO;

    }

    /// Initialize the stack.
    /// Params:
    ///     next = Node to draw using the stack.
    this(Node next = null) {

        import fluid.structs : layout;

        chain(
            preferenceIO = preferenceChain(),
            timeIO       = timeChain(),
            actionIO     = inputMapChain(),
            focusIO      = focusChain(),
            hoverIO      = hoverChain(),
            fileIO       = fileChain(),
            raylibIO     = raylibView(
                chain(
                    overlayIO = overlayChain(
                        layout!(1, "fill")
                    ),
                    next,
                ),
            ),
        );

    }

    /// Returns:
    ///     The first node in the stack.
    inout(NodeChain) root() inout {
        return preferenceIO;
    }

    /// Returns:
    ///     Top node of the stack, before `next`
    inout(NodeChain) top() inout {
        return overlayIO;
    }

    /// Returns:
    ///     The node contained by the stack, child node of the `top`.
    inout(Node) next() inout {
        return top.next;
    }

    /// Change the node contained by the stack.
    /// Params:
    ///     value = Value to set.
    /// Returns:
    ///     Newly set node.
    Node next(Node value) {
        return top.next = value;
    }

    override void drawTree(TreeContext context, Node root) {
        this.next = root;
        this.treeContext = context;
        drawAsRoot();
    }

    override void runTree(TreeContext context, Node root) @trusted {
        import std.algorithm : max;

        SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE | ConfigFlags.FLAG_WINDOW_HIDDEN);
        SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
        InitWindow(800, 600, "Fluid app");
        SetTargetFPS(60);
        scope (exit) CloseWindow();

        void draw() {
            BeginDrawing();
            ClearBackground(color("fff"));
            drawTree(context, root);
            EndDrawing();
        }

        // Probe the node for information
        draw();

        // Set window size
        auto min = root.getMinSize;
        int minX = cast(int) min.x;
        int minY = cast(int) min.y;
        SetWindowMinSize(minX, minY);
        SetWindowSize(minX, minY);

        // Now draw
        ClearWindowState(ConfigFlags.FLAG_WINDOW_HIDDEN);

        // Event loop
        while (!WindowShouldClose) {
            draw();
        }
    }

    override void resizeImpl(Vector2 space) {
        resizeChild(root, space);
        minSize = root.minSize;
    }

    override void drawImpl(Rectangle, Rectangle inner) {
        drawChild(root, inner);
    }

}

/// Convert a `MouseIO.Button` to a `raylib.MouseButton`.
///
/// Note:
///     `raylib.MouseButton` does not have a dedicated invalid value so this function will instead
///     return `-1`.
/// Params:
///     button = A Fluid `MouseIO` button code.
/// Returns:
///     A corresponding `raylib.MouseButton` value, `-1` if there isn't one.
int toRaylib(MouseIO.Button button) {

    with (MouseButton)
    with (button)
    final switch (button) {

        case none:    return -1;
        case left:    return MOUSE_BUTTON_LEFT;
        case right:   return MOUSE_BUTTON_RIGHT;
        case middle:  return MOUSE_BUTTON_MIDDLE;
        case extra1:  return MOUSE_BUTTON_SIDE;
        case extra2:  return MOUSE_BUTTON_EXTRA;
        case forward: return MOUSE_BUTTON_FORWARD;
        case back:    return MOUSE_BUTTON_BACK;

    }

}

/// Convert a Raylib keyboard key to a `KeyboardIO.Key` code.
///
/// Params:
///     button = A Raylib `KeyboardKey` key code.
/// Returns:
///     A corresponding `KeyboardIO.Key` value. `KeyboardIO.Key.none` if the key is not recognized.
KeyboardIO.Key toFluid(KeyboardKey key) {

    with (KeyboardIO.Key)
    with (KeyboardKey)
    final switch (key) {

        case KEY_NULL:          return none;
        case KEY_APOSTROPHE:    return apostrophe;
        case KEY_COMMA:         return comma;
        case KEY_MINUS:         return minus;
        case KEY_PERIOD:        return period;
        case KEY_SLASH:         return slash;
        case KEY_ZERO:          return digit0;
        case KEY_ONE:           return digit1;
        case KEY_TWO:           return digit2;
        case KEY_THREE:         return digit3;
        case KEY_FOUR:          return digit4;
        case KEY_FIVE:          return digit5;
        case KEY_SIX:           return digit6;
        case KEY_SEVEN:         return digit7;
        case KEY_EIGHT:         return digit8;
        case KEY_NINE:          return digit9;
        case KEY_SEMICOLON:     return semicolon;
        case KEY_EQUAL:         return equal;
        case KEY_A:             return a;
        case KEY_B:             return b;
        case KEY_C:             return c;
        case KEY_D:             return d;
        case KEY_E:             return e;
        case KEY_F:             return f;
        case KEY_G:             return g;
        case KEY_H:             return h;
        case KEY_I:             return i;
        case KEY_J:             return j;
        case KEY_K:             return k;
        case KEY_L:             return l;
        case KEY_M:             return m;
        case KEY_N:             return n;
        case KEY_O:             return o;
        case KEY_P:             return p;
        case KEY_Q:             return q;
        case KEY_R:             return r;
        case KEY_S:             return s;
        case KEY_T:             return t;
        case KEY_U:             return u;
        case KEY_V:             return v;
        case KEY_W:             return w;
        case KEY_X:             return x;
        case KEY_Y:             return y;
        case KEY_Z:             return z;
        case KEY_LEFT_BRACKET:  return leftBracket;
        case KEY_BACKSLASH:     return backslash;
        case KEY_RIGHT_BRACKET: return rightBracket;
        case KEY_GRAVE:         return grave;
        case KEY_SPACE:         return space;
        case KEY_ESCAPE:        return escape;
        case KEY_ENTER:         return enter;
        case KEY_TAB:           return tab;
        case KEY_BACKSPACE:     return backspace;
        case KEY_INSERT:        return insert;
        case KEY_DELETE:        return delete_;
        case KEY_RIGHT:         return right;
        case KEY_LEFT:          return left;
        case KEY_DOWN:          return down;
        case KEY_UP:            return up;
        case KEY_PAGE_UP:       return pageUp;
        case KEY_PAGE_DOWN:     return pageDown;
        case KEY_HOME:          return home;
        case KEY_END:           return end;
        case KEY_CAPS_LOCK:     return capsLock;
        case KEY_SCROLL_LOCK:   return scrollLock;
        case KEY_NUM_LOCK:      return numLock;
        case KEY_PRINT_SCREEN:  return printScreen;
        case KEY_PAUSE:         return pause;
        case KEY_F1:            return f1;
        case KEY_F2:            return f2;
        case KEY_F3:            return f3;
        case KEY_F4:            return f4;
        case KEY_F5:            return f5;
        case KEY_F6:            return f6;
        case KEY_F7:            return f7;
        case KEY_F8:            return f8;
        case KEY_F9:            return f9;
        case KEY_F10:           return f10;
        case KEY_F11:           return f11;
        case KEY_F12:           return f12;
        case KEY_LEFT_SHIFT:    return leftShift;
        case KEY_LEFT_CONTROL:  return leftControl;
        case KEY_LEFT_ALT:      return leftAlt;
        case KEY_LEFT_SUPER:    return leftSuper;
        case KEY_RIGHT_SHIFT:   return rightShift;
        case KEY_RIGHT_CONTROL: return rightControl;
        case KEY_RIGHT_ALT:     return rightAlt;
        case KEY_RIGHT_SUPER:   return rightSuper;
        case KEY_KB_MENU:       return contextMenu;
        case KEY_KP_0:          return keypad0;
        case KEY_KP_1:          return keypad1;
        case KEY_KP_2:          return keypad2;
        case KEY_KP_3:          return keypad3;
        case KEY_KP_4:          return keypad4;
        case KEY_KP_5:          return keypad5;
        case KEY_KP_6:          return keypad6;
        case KEY_KP_7:          return keypad7;
        case KEY_KP_8:          return keypad8;
        case KEY_KP_9:          return keypad9;
        case KEY_KP_DECIMAL:    return keypadDecimal;
        case KEY_KP_DIVIDE:     return keypadDivide;
        case KEY_KP_MULTIPLY:   return keypadMultiply;
        case KEY_KP_SUBTRACT:   return keypadSubtract;
        case KEY_KP_ADD:        return keypadSum;
        case KEY_KP_ENTER:      return keypadEnter;
        case KEY_KP_EQUAL:      return keypadEqual;
        case KEY_BACK:          return androidBack;
        case KEY_MENU:          return androidMenu;
        case KEY_VOLUME_UP:     return volumeUp;
        case KEY_VOLUME_DOWN:   return volumeDown;

    }

}

fluid.Image toFluid(raylib.Image imageRay) @trusted {

    auto colors = LoadImageColors(imageRay);
    scope (exit) UnloadImageColors(colors);

    const size = imageRay.width * imageRay.height;

    return fluid.Image(colors[0 .. size].dup, imageRay.width, imageRay.height);

}

enum ImageType : string {

    none = "",
    png = ".png",
    bmp = ".bmp",
    tga = ".tga",
    jpg = ".jpg",
    gif = ".gif",
    qoi = ".qoi",
    psd = ".psd",
    dds = ".dds",
    hdr = ".hdr",
    pic = ".pic",
    ktx = ".ktx",
    astc = ".astc",
    pkm = ".pkm",
    pvr = ".pvr",

}

/// Identify image type by contents.
/// Params:
///     image = File data of the image to identify.
/// Returns:
///     String containing the image extension, or an empty string indicating unknown file.
ImageType identifyImageType(const ubyte[] data) {

    import std.algorithm : predSwitch;
    import std.conv : hexString;


    return data.predSwitch!"a.startsWith(cast(const ubyte[]) b)"(
        // Source: https://en.wikipedia.org/wiki/List_of_file_signatures
        hexString!"89 50 4E 47 0D 0A 1A 0A",             ImageType.png,
        hexString!"42 4D",                               ImageType.bmp,
        hexString!"FF D8 FF E0 00 10 4A 46 49 46 00 01", ImageType.jpg,
        hexString!"FF D8 FF EE",                         ImageType.jpg,
        hexString!"FF D8 FF E1",                         ImageType.jpg,
        hexString!"FF D8 FF E0",                         ImageType.jpg,
        hexString!"00 00 00 0C 6A 50 20 20 0D 0A 87 0A", ImageType.jpg,
        hexString!"FF 4F FF 51",                         ImageType.jpg,
        hexString!"47 49 46 38 37 61",                   ImageType.gif,
        hexString!"47 49 46 38 39 61",                   ImageType.gif,
        hexString!"71 6f 69 66",                         ImageType.qoi,
        hexString!"38 42 50 53",                         ImageType.psd,
        hexString!"23 3F 52 41 44 49 41 4E 43 45 0A",    ImageType.hdr,
        hexString!"6E 69 31 00",                         ImageType.hdr,
        hexString!"00",                                  ImageType.pic,
        // Source: https://en.wikipedia.org/wiki/DirectDraw_Surface
        hexString!"44 44 53 20",                         ImageType.dds,
        // Source: https://paulbourke.net/dataformats/ktx/
        hexString!"AB 4B 54 58 20 31 31 BB 0D 0A 1A 0A", ImageType.ktx,
        // Source: https://github.com/ARM-software/astc-encoder/blob/main/Docs/FileFormat.md
        hexString!"13 AB A1 5C",                         ImageType.astc,
        // Source: https://stackoverflow.com/questions/35881537/how-to-decode-this-image
        hexString!"50 4B 4D 20",                         ImageType.pkm,
        // Source: http://powervr-graphics.github.io/WebGL_SDK/WebGL_SDK/Documentation/Specifications/PVR%20File%20Format.Specification.pdf
        hexString!"03 52 56 50",                         ImageType.pvr,
        hexString!"50 56 52 03",                         ImageType.pvr,
        // Source: https://en.wikipedia.org/wiki/Truevision_TGA
        data.endsWith("TRUEVISION-XFILE.\0")
            ? ImageType.tga
            : ImageType.none,
    );

}

/// Convert image to a Raylib image. Do not call `UnloadImage` on the result.
raylib.Image toRaylib(fluid.Image image) nothrow @trusted {
    raylib.Image result;
    result.data = image.data.ptr;
    result.width = image.width;
    result.height = image.height;
    result.format = image.format.toRaylib;
    result.mipmaps = 1;
    return result;
}

/// Convert Fluid image format to Raylib's closest alternative.
raylib.PixelFormat toRaylib(fluid.Image.Format imageFormat) nothrow {
    final switch (imageFormat) {
        case imageFormat.rgba:
            return PixelFormat.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8;
        case imageFormat.palettedAlpha:
            return PixelFormat.PIXELFORMAT_UNCOMPRESSED_GRAY_ALPHA;
        case imageFormat.alpha:
            return PixelFormat.PIXELFORMAT_UNCOMPRESSED_GRAYSCALE;
    }
}

/// Get the Raylib enum for a mouse cursor.
raylib.MouseCursor toRaylib(Cursor.SystemCursors cursor) {
    with (raylib.MouseCursor)
    with (Cursor.SystemCursors)
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

