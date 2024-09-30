module fluid.graphics;

import fluid.backend;
public import raylib.raylib_types;

version (Have_raylib_d) {
    public import raylib : Color;
}

@safe:

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
    data[] = PalettedColor(0, alpha);

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

    ubyte index;
    ubyte alpha;

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

    unittest {

        auto colors = [
            PalettedColor(0, ubyte(0)),
            PalettedColor(1, ubyte(127)),
            PalettedColor(2, ubyte(127)),
            PalettedColor(3, ubyte(255)),
        ];

        auto image = Image(colors, 2, 2);
        image.palette = [
            Color(0, 0, 0, 255),
            Color(255, 0, 0, 255),
            Color(0, 255, 0, 255),
            Color(0, 0, 255, 255),
        ];

        assert(image.get(0, 0) == Color(0, 0, 0, 0));
        assert(image.get(1, 0) == Color(255, 0, 0, 127));
        assert(image.get(0, 1) == Color(0, 255, 0, 127));
        assert(image.get(1, 1) == Color(0, 0, 255, 255));

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

        import std.array;
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

    import std.conv: to;
    import std.string : chompPrefix;

    // Remove the # if there is any
    const hex = hexCode.chompPrefix("#");

    Color result;
    result.a = 0xff;

    switch (hex.length) {

        // 4 digit RGBA
        case 4:
            result.a = hex[3..4].to!ubyte(16);
            result.a *= 17;

            // Parse the rest like RGB
            goto case;

        // 3 digit RGB
        case 3:
            result.r = hex[0..1].to!ubyte(16);
            result.g = hex[1..2].to!ubyte(16);
            result.b = hex[2..3].to!ubyte(16);
            result.r *= 17;
            result.g *= 17;
            result.b *= 17;
            break;

        // 8 digit RGBA
        case 8:
            result.a = hex[6..8].to!ubyte(16);
            goto case;

        // 6 digit RGB
        case 6:
            result.r = hex[0..2].to!ubyte(16);
            result.g = hex[2..4].to!ubyte(16);
            result.b = hex[4..6].to!ubyte(16);
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

Color setAlpha()(Color, int) {

    static assert(false, "Overload setAlpha(Color, int) is ambiguous. Explicitly choose "
        ~ "setAlpha(Color, float) (0...1 range) or "
        ~ "setAlpha(Color, ubyte) (0...255 range)");

}

/// Set the alpha channel for the given color, as a float.
Color setAlpha(Color color, ubyte alpha) {

    color.a = alpha;
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
