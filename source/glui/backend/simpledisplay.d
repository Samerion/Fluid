module glui.backend.simpledisplay;

version (Have_arsd_official_simpledisplay):

debug (Glui_BuildMessages) {
    pragma(msg, "Glui: Building with arsd.simpledisplay support");
}

import arsd.simpledisplay;
import std.datetime.stopwatch;

import glui.backend;


@safe:


private {
    alias Rectangle = glui.backend.Rectangle;
    alias Color = glui.backend.Color;
    alias Image = glui.backend.Image;
}

class SimpledisplayBackend : GluiBackend {

    SimpleWindow window;

    private {

        Vector2 _mousePosition;
        int _dpi;
        bool _hasJustResized;
        StopWatch _stopWatch;
        float _deltaTime;
        Rectangle _scissors;
        bool _scissorsEnabled;

        // Missing from simpledisplay at the time of writing
        extern(C) void function(GLint x, GLint y, GLsizei width, GLsizei height) glScissor;

    }

    // TODO non-openGL backend

    /// Initialize the backend using the given window. Please note Glui will register its own event handlers, so if you
    /// intend to use them, you should make sure to call whatever value was set previously.
    ///
    /// ---
    /// auto oldMouseHandler = window.handleMouseEvent;
    /// window.handleMouseEvent = (MouseEvent event) {
    ///     oldMouseHandler(event);
    ///     // ... do your stuff ...
    /// };
    /// ---
    this(SimpleWindow window) {

        this.window = window;

        () @trusted {
            this.glScissor = cast(typeof(glScissor)) glbindGetProcAddress("glScissor");
        }();

        updateDPI();
        _stopWatch.start();

        auto oldPaintingFinished = window.paintingFinished;
        auto oldMouseHandler = window.handleMouseEvent;
        auto oldWindowResized = window.windowResized;
        auto oldOnDpiChanged = window.onDpiChanged;

        // Frame event
        this.window.paintingFinished = () {

            if (oldPaintingFinished) oldPaintingFinished();

            // Calculate delta time
            _deltaTime = _stopWatch.peek.total!"msecs" / 1000f;
            _stopWatch.reset();

            // Reset frame state
            _hasJustResized = false;

        };

        // Register a mouse handler
        this.window.handleMouseEvent = (MouseEvent event) {

            if (oldMouseHandler) oldMouseHandler(event);

            // Update mouse position
            _mousePosition = Vector2(event.x, event.y);

        };

        // Register a resize handler
        this.window.windowResized = (int width, int height) {

            if (oldWindowResized) oldWindowResized(width, height);

            // Update window size
            _hasJustResized = true;
            glViewport(0, 0, width, height);

        };

        this.window.onDpiChanged = () {

            if (oldOnDpiChanged) oldOnDpiChanged();

            // Update window size
            _hasJustResized = true;
            updateDPI();

        };

    }

    @trusted {

        bool isPressed(GluiMouseButton button) const => false;
        bool isReleased(GluiMouseButton button) const => false;
        bool isDown(GluiMouseButton button) const => false;
        bool isUp(GluiMouseButton button) const => false;

        bool isPressed(GluiKeyboardKey key) const => false;
        bool isReleased(GluiKeyboardKey key) const => false;
        bool isDown(GluiKeyboardKey key) const => false;
        bool isUp(GluiKeyboardKey key) const => false;

        bool isRepeated(GluiKeyboardKey key) const => false;
        dchar inputCharacter() => '\0';

        bool isPressed(int controller, GluiGamepadButton button) const
            => false;
        bool isReleased(int controller, GluiGamepadButton button) const
            => false;
        bool isDown(int controller, GluiGamepadButton button) const
            => false;
        bool isUp(int controller, GluiGamepadButton button) const
            => false;

    }

    private void updateDPI() @trusted {

        import std.algorithm;

        _dpi = either(window.actualDpi, 96);

    }

    Vector2 mousePosition(Vector2 position) @trusted {

        window.warpMouse(cast(int) position.x, cast(int) position.y);
        return _mousePosition = position;

    }

    Vector2 mousePosition() const @trusted {

        return _mousePosition;

    }

    float deltaTime() const @trusted {

        return _deltaTime;

    }

    bool hasJustResized() const @trusted {

        // TODO handle resize event
        return _hasJustResized;

    }

    Vector2 windowSize(Vector2 size) @trusted {

        window.resize(cast(int) size.x, cast(int) size.y);
        return size;

    }

    Vector2 windowSize() const @trusted {

        return Vector2(window.width, window.height);

    }

    /// Convert window coordinates to OpenGL coordinates.
    Vector2 toGL(Vector2 coords) {

        return Vector2(
            coords.x / windowSize.x * 2 - 1,
            1 - coords.y / windowSize.y * 2
        );

    }

    /// Create a vertex at given screenspace position
    void vertex(Vector2 coords) @trusted {

        glVertex2f(toGL(coords).tupleof);

    }

    Vector2 hidpiScale() const @trusted {

        return Vector2(_dpi / 96f, _dpi / 96f);

    }

    Rectangle area(Rectangle rect) @trusted {

        glEnable(GL_SCISSOR_TEST);
        glScissor(
            cast(int) rect.x,
            cast(int) (window.height - rect.y - rect.height),
            cast(int) rect.width,
            cast(int) rect.height,
        );
        _scissorsEnabled = true;

        return _scissors = rect;

    }

    Rectangle area() const {

        if (_scissorsEnabled)
            return _scissors;
        else
            return Rectangle(0, 0, windowSize.tupleof);

    }

    void restoreArea() @trusted {

        glDisable(GL_SCISSOR_TEST);
        _scissorsEnabled = false;

    }

    GluiMouseCursor mouseCursor(GluiMouseCursor cursor) @trusted {

        return cursor;

    }

    GluiMouseCursor mouseCursor() const {

        return GluiMouseCursor.init;

    }

    Texture loadTexture(Image image) @system {

        Texture result;
        result.backend = this;
        result.width = image.width;
        result.height = image.height;

        // Create an OpenGL texture
        glGenTextures(1, &result.id);
        glBindTexture(GL_TEXTURE_2D, result.id);

        // No filtering
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

        // Repeat on
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

        // Upload the data
        glTexImage2D(

            // 2D texture, no mipmaps, four channels
            GL_TEXTURE_2D, 0, GL_RGBA,

            // Size
            image.width, image.height,

            // No border
            0,

            // Formatted as R8B8G8A8
            GL_RGBA, GL_UNSIGNED_BYTE, image.pixels.ptr,

        );

        // Unbind the texture
        glBindTexture(GL_TEXTURE_2D, 0);

        return result;

    }

    Image loadImage(string filename) @system {

        version (Have_arsd_official_image_files) {

            import arsd.image;

            // Load the image
            auto image = loadImageFromFile(filename).getAsTrueColorImage;

            // Convert to a Glui image
            Image result;
            result.pixels = cast(Color[]) image.imageData.bytes;
            result.width = image.width;
            result.height = image.height;
            return result;

        }

        else assert(false, "arsd-official:image_files is required to load images from files");

    }

    Texture loadTexture(string filename) @system {

        return loadTexture(loadImage(filename));

    }

    /// Destroy a texture
    void unloadTexture(Texture texture) @system {

        if (texture.id == 0) return;

        glDeleteTextures(1, &texture.id);

    }

    private void openglDraw() @trusted {

        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glEnable(GL_BLEND);
        glLoadIdentity();

    }

    void drawLine(Vector2 start, Vector2 end, Color color) @trusted {

        openglDraw();
        glBegin(GL_LINES);

        glColor4ub(color.tupleof);
        vertex(start);
        vertex(end);

        glEnd();

    }

    void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) @trusted {

        openglDraw();
        glBegin(GL_TRIANGLES);
        glColor4ub(color.tupleof);
        vertex(a);
        vertex(b);
        vertex(c);
        glEnd();

    }

    void drawRectangle(Rectangle rectangle, Color color) @trusted {

        import glui.utils;

        openglDraw();
        glBegin(GL_TRIANGLES);

        glColor4ub(color.tupleof);

        //  d--c
        //  | /|
        //  |/ |
        //  a--b
        const a = start(rectangle) + Vector2(0, rectangle.height);
        const b = end(rectangle);
        const d = start(rectangle);
        const c = start(rectangle) + Vector2(rectangle.width, 0);

        // First triangle
        glTexCoord2f(0, 0);
        vertex(d);
        glColor4ub(color.tupleof);
        glTexCoord2f(0, 1);
        vertex(a);
        glColor4ub(color.tupleof);
        glTexCoord2f(1, 0);
        vertex(c);

        // Second triangle
        glColor4ub(color.tupleof);
        glTexCoord2f(1, 0);
        vertex(c);
        glColor4ub(color.tupleof);
        glTexCoord2f(0, 1);
        vertex(a);
        glColor4ub(color.tupleof);
        glTexCoord2f(1, 1);
        vertex(b);

        glEnd();

    }

    void drawTexture(Texture texture, Vector2 position, Color tint) @trusted {

        auto rectangle = Rectangle(position.tupleof, texture.width, texture.height);

        glEnable(GL_TEXTURE_2D);
        glBindTexture(GL_TEXTURE_2D, texture.id);
        drawRectangle(rectangle, tint);
        glBindTexture(GL_TEXTURE_2D, 0);

    }

}
