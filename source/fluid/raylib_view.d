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
///
/// Unlike `fluid.backend.Raylib5Backend`, this uses the new I/O system introduced in Fluid 0.8.0. This layer
/// is recommended for new apps, but disabled by default.
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

import fluid.node;
import fluid.utils;
import fluid.types;
import fluid.node_chain;

import fluid.future.arena;

import fluid.backend.raylib5 : Raylib5Backend, toRaylib;

import fluid.io.canvas;
import fluid.io.hover;
import fluid.io.mouse;

static if (!__traits(compiles, IsShaderReady))
    private alias IsShaderReady = IsShaderValid;

@safe:

/// `raylibStack` implements all I/O functionality needed for Fluid to function, using Raylib to read user input
/// and present visuals on the screen.
///
/// Specify Raylib version by using a member: `raylibStack.v5_5()` will create a stack for Raylib 5.5.
///
/// `raylibStack` provides a default implementation for `HoverIO`, `FocusIO`, `ActionIO` and `FileIO`, on top of all
/// the systems provided by Raylib itself: `CanvasIO`, `KeyboardIO`, `MouseIO`, `ClipboardIO` and `ImageLoadIO`.
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
class RaylibView(RaylibViewVersion raylibVersion) : Node, CanvasIO, MouseIO {

    HoverIO hoverIO;

    public {

        /// Node drawn by this view.
        Node next;

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
        Pointer _mousePointer;

    }

    this(Node next = null) {
        this.next = next;
    }

    override void resizeImpl(Vector2) @trusted {

        require(hoverIO);
        hoverIO.loadTo(_mousePointer);

        // Fetch data from Raylib
        _dpiScale = GetWindowScaleDPI;
        _dpi = Vector2(_dpiScale.x * 96, _dpiScale.y * 96);
        _windowSize = toFluid(GetScreenWidth, GetScreenHeight);
        resetCropArea();

        // Load shaders
        if (!IsShaderReady(_alphaImageShader)) {
            _alphaImageShader = LoadShaderFromMemory(null, Raylib5Backend.alphaImageShaderCode.ptr);
        }
        if (!IsShaderReady(_palettedAlphaImageShader)) {
            _palettedAlphaImageShader = LoadShaderFromMemory(null, Raylib5Backend.palettedAlphaImageShaderCode.ptr);
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

    override void drawImpl(Rectangle, Rectangle) {

        updateMouse();

        if (next) {
            resetCropArea();
            drawChild(next, _cropArea);
        }

    }

    protected void updateMouse() @trusted {

        // Update mouse status
        _mousePointer.position     = toFluid(GetMousePosition);
        _mousePointer.scroll       = scroll();
        _mousePointer.isScrollHeld = false;
        hoverIO.loadTo(_mousePointer);

        // Send buttons
        foreach (button; NoDuplicates!(EnumMembers!(MouseIO.Button))) {

            const buttonRay = .toRaylibEx(button);

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

    /// Returns:
    ///     Distance travelled by the mouse in Fluid coordinates.
    private Vector2 scroll() @trusted {

        // Normalize the value: Linux and Windows provide trinary values (-1, 0, 1) but macOS gives analog that often
        // goes far higher than that. This is a rough guess of the proportions based on feeling.
        version (OSX)
            return -GetMouseWheelMoveV / 4;
        else
            return -GetMouseWheelMoveV;

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

        auto texture = _images[image.id].texture;

        DrawTexturePro(texture, source, destinationRay, Vector2(0, 0), 0, tint);

        // End shaders
        if (IsShaderReady(shader))
            EndShaderMode();

    }

    override int load(fluid.Image image) nothrow @trusted {

        const id = cast(size_t) image.data.ptr;

        // Image already loaded, reuse
        if (auto indexPtr = id in _imageIndices) {

            auto resource = _images[*indexPtr];

            // Image was updated, mirror the changes
            if (image.revisionNumber > resource.image.revisionNumber) {

                const sameFormat = resource.image.width == image.width
                    && resource.image.height == image.height
                    && resource.image.format == image.format;

                resource.image = image;

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

        // Load the image
        else {
            auto texture = LoadTextureFromImage(image.toRaylib);
            auto internalImage = RaylibImage(image, texture);

            return _imageIndices[id] = _images.load(internalImage);
        }
    }


}

/// A complete implementation of all systems Fluid needs to function, using Raylib as the base for communicating with
/// the operating system. Use `raylibStack` to construct.
///
/// For a minimal installation that only includes systems provided by Raylib use `RaylibView`.
/// Note that `RaylibView` does not provide all the systems Fluid needs to function. See its documentation for more
/// information.
///
/// On top of systems already provided by `RaylibView`, `RaylibStack` also includes `HoverIO`, `FocusIO`, `ActionIO`
/// and `FileIO`. You can access them through fields named `hoverIO`, `focusIO`, `actionIO` and `fileIO` respectively.
class RaylibStack(RaylibViewVersion raylibVersion) : Node {

    import fluid.hover_chain;
    import fluid.focus_chain;
    import fluid.input_map_chain;
    import fluid.file_chain;

    public {

        /// I/O implementations provided by the stack.
        HoverChain hoverIO;

        /// ditto
        FocusChain focusIO;

        /// ditto
        InputMapChain actionIO;

        /// ditto
        FileChain fileIO;

        /// ditto
        RaylibView!raylibVersion raylibIO;

    }

    /// Initialize the stack.
    /// Params:
    ///     next = Node to draw using the stack.
    this(Node next) {

        chain(
            actionIO = inputMapChain(),
            hoverIO  = hoverChain(),
            focusIO  = focusChain(),
            fileIO   = fileChain(),
            raylibIO = raylibView(next),
        );

    }

    /// Returns:
    ///     The first node in the stack.
    inout(NodeChain) root() inout {
        return actionIO;
    }

    /// Returns:
    ///     The last node in the stack, child node of the `RaylibView`.
    ref inout(Node) next() inout {
        return raylibIO.next;
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
/// Temporarily named `toRaylibEx` instead of `toRaylib` to avoid conflicts with legacy Raylib functionality.
///
/// Note:
///     `raylib.MouseButton` does not have a dedicated invalid value so this function will instead
///     return `-1`.
/// Params:
///     button = A Fluid `MouseIO` button code.
/// Returns:
///     A corresponding `raylib.MouseButton` value.
int toRaylibEx(MouseIO.Button button) {

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
