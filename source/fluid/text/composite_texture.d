/// To make it more efficient to render large quantities of text, Fluid render texts to a mosaic of textures rather
/// than a single individual texture, making it possible to render only small parts of text at a time.
module fluid.text.composite_texture;

import std.math;
import std.range;
import std.format;
import std.algorithm;
debug (Fluid_TextUpdates) {
    import std.datetime;
}

import fluid.utils;
import fluid.io.canvas;

debug (Fluid_BuildMessages) {
    debug (Fluid_TextUpdates) {
        pragma(msg, "Fluid: Highlight updated texture chunks is on");
    }
    debug (Fluid_TextChunks) {
        pragma(msg, "Fluid: Displaying text chunk grid is on");
    }
}

@safe:

/// A composite texture splits a larger area onto smaller chunks, making rendering large pieces of text more efficient.
struct CompositeTexture {

    enum maxChunkSize = 512;

    struct Chunk {

        TextureGC texture;
        DrawableImage image;
        bool isValid;

        debug (Fluid_TextUpdates) {
            SysTime lastEdit;
        }

        alias texture this;

    }

    /// Format of the texture.
    Image.Format format;

    /// Total size of the texture.
    Vector2 size;

    /// DPI of the texture.
    Vector2 dpi;

    /// Underlying textures.
    ///
    /// Each texture, except for the last in each column or row, has the size of maxChunkSize on each side. The last
    /// texture in each row and column may have reduced width and height respectively.
    Chunk[] chunks;

    /// Palette to use for the texture, if relevant.
    Color[] palette;

    private bool _alwaysMax;

    this(Vector2 size, Vector2 dpi, bool alwaysMax = false) {
        resize(size, dpi, alwaysMax);
    }

    deprecated this(Vector2 size, bool alwaysMax = false) {
        resize(size, alwaysMax);
    }

    Vector2 viewportSize() const pure nothrow {
        return Vector2(
            size.x * 96f / dpi.x,
            size.y * 96f / dpi.y
        );
    }

    /// Set a new size for the texture; recalculate the chunk number
    /// Params:
    ///     size      = New size of the texture.
    ///     dpi       = DPI value for the texture.
    ///     alwaysMax = Always give chunks maximum size. Improves performance in nodes that
    ///         frequently change their content.
    void resize(Vector2 size, Vector2 dpi, bool alwaysMax = false) {
        this.size = size;
        this.dpi = dpi;
        this._alwaysMax = alwaysMax;

        const chunkCount = columns * rows;

        this.chunks.length = chunkCount;

        // Invalidate the chunks
        foreach (ref chunk; chunks) {
            chunk.isValid = false;
        }
    }

    deprecated void resize(Vector2 size, bool alwaysMax = false) {
        resize(size, Vector2(96, 96), alwaysMax);
    }

    size_t chunkCount() const {
        return chunks.length;
    }

    size_t columns() const {
        return cast(size_t) ceil(size.x / maxChunkSize);
    }

    size_t rows() const {
        return cast(size_t) ceil(size.y / maxChunkSize);
    }

    size_t column(size_t i) const {
        return i % columns;
    }

    size_t row(size_t i) const {
        return i / columns;
    }

    /// Get the expected size of the chunk at given index
    Vector2 chunkSize(size_t i) const {

        // Return max chunk size if requested
        if (_alwaysMax)
            return Vector2(maxChunkSize, maxChunkSize);

        const x = column(i);
        const y = row(i);

        // Reduce size for last column
        const width = x + 1 == columns
            ? size.x % maxChunkSize
            : maxChunkSize;

        // Reduce size for last row
        const height = y + 1 == rows
            ? size.y % maxChunkSize
            : maxChunkSize;

        return Vector2(width, height);

    }

    Vector2 chunkViewportSize(size_t i) const {
        const size = chunkSize(i);
        return Vector2(
            size.x * 96 / dpi.x,
            size.y * 96 / dpi.y,
        );
    }

    /// Get index of the chunk at given X or Y.
    size_t index(size_t x, size_t y) const
    in (x < columns)
    in (y < rows)
    do {
        return x + y * columns;
    }

    /// Get position of the given chunk in dots.
    Vector2 chunkPosition(size_t i) const {
        const x = column(i);
        const y = row(i);
        return maxChunkSize * Vector2(x, y);
    }

    /// Get position of the given chunk in pixels.
    Vector2 chunkViewportPosition(size_t i) const {
        const position = chunkPosition(i);
        return Vector2(
            position.x * 96 / dpi.x,
            position.y * 96 / dpi.y,
        );
    }

    /// Get the rectangle of the given chunk in dots.
    /// Params:
    ///     i      = Index of the chunk.
    ///     offset = Translate the resulting rectangle by this vector.
    Rectangle chunkRectangle(size_t i, Vector2 offset = Vector2()) const {
        return Rectangle(
            (chunkPosition(i) + offset).tupleof,
            chunkSize(i).tupleof,
        );
    }

    /// ditto
    Rectangle chunkViewportRectangle(size_t i, Vector2 offset = Vector2()) const {
        return Rectangle(
            (chunkViewportPosition(i) + offset).tupleof,
            chunkViewportSize(i).tupleof,
        );
    }

    /// Get a range of indices for all chunks.
    const allChunks() {
        return visibleChunks(Vector2(), viewportSize);

    }

    /// Get a range of indices for all currently visible chunks.
    ///
    /// Loads all chunks if no `cropArea` is set.
    const visibleChunks(CanvasIO canvasIO, Vector2 position) {
        const area = canvasIO.cropArea;
        if (area.empty) {
            return allChunks;
        }
        else {
            return visibleChunks(
                position - area.front.start,
                area.front.size);
        }
    }

    /// Get a range of indices for all currently visible chunks.
    const visibleChunks(Vector2 position, Vector2 windowSize) {

        const offsetPx = -position;
        const endPx = offsetPx + windowSize;

        const offset = Vector2(
            offsetPx.x * dpi.x / 96,
            offsetPx.y * dpi.y / 96,
        );
        const end = Vector2(
            endPx.x * dpi.x / 96,
            endPx.y * dpi.y / 96,
        );

        ptrdiff_t positionToIndex(alias round)(float position, ptrdiff_t limit) {
            const index = cast(ptrdiff_t) round(position / maxChunkSize);
            return index.clamp(0, limit);
        }

        const rowStart = positionToIndex!floor(offset.y, rows);
        const rowEnd = positionToIndex!ceil(end.y, rows);
        const columnStart = positionToIndex!floor(offset.x, columns);
        const columnEnd = positionToIndex!ceil(end.x, columns);

        // For each row
        return iota(rowStart, rowEnd)
            .map!(row =>

                // And each column
                iota(columnStart, columnEnd)

                    // Get its index
                    .map!(column => index(column, row)))
            .joiner;

    }

    /// Clear the image of the given chunk, making it transparent.
    void clearImage(size_t i) {

        const size = chunkSize(i);
        const width = cast(int) size.x;
        const height = cast(int) size.y;

        // Check if the size of the chunk has changed
        const sizeMatches = chunks[i].image.width == width
            && chunks[i].image.height == height;

        debug (Fluid_TextUpdates) {
            chunks[i].lastEdit = Clock.currTime;
        }

        // Size matches, reuse the image
        if (sizeMatches)
            chunks[i].image.clear(PalettedColor.init);

        // No match, generate a new image
        else final switch (format) {

            case format.rgba:
                chunks[i].image = generateColorImage(width, height, color("#0000"));
                return;

            case format.palettedAlpha:
                chunks[i].image = generatePalettedImage(width, height, 0);
                return;

            case format.alpha:
                chunks[i].image = generateAlphaMask(width, height, 0);
                return;

        }

    }

    /// Update the texture of a given chunk using its corresponding image.
    void upload(FluidBackend backend, size_t i, Vector2 dpi) @trusted {

        const sizeMatches = chunks[i].image.width == chunks[i].texture.width
            && chunks[i].image.height == chunks[i].texture.height;

        // Size is the same as before, update the texture
        if (sizeMatches) {

            assert(chunks[i].texture.backend !is null);
            debug assert(backend == chunks[i].texture.backend,
                .format!"Backend mismatch %s != %s"(backend, chunks[i].texture.backend));

            chunks[i].texture.update(chunks[i].image);

        }

        // No match, create a new texture
        else {

            chunks[i].texture = TextureGC(backend, chunks[i].image);

        }

        // Update DPI
        chunks[i].texture.dpiX = cast(int) dpi.x;
        chunks[i].texture.dpiY = cast(int) dpi.y;

        // Mark as valid
        chunks[i].isValid = true;

        debug (Fluid_TextUpdates) {
            chunks[i].lastEdit = Clock.currTime;
        }

    }

    /// Update the texture of a given chunk using its corresponding image.
    void upload(CanvasIO canvasIO, size_t index, Vector2 dpi) @trusted {

        // Update texture DPI
        chunks[index].image.dpiX = cast(int) dpi.x;
        chunks[index].image.dpiY = cast(int) dpi.y;

        // Mark as valid
        chunks[index].isValid = true;

        // Bump revision number
        chunks[index].image.revisionNumber++;

        chunks[index].image.load(canvasIO,
            canvasIO.load(chunks[index].image));

        debug (Fluid_TextUpdates) {
            chunks[index].lastEdit = Clock.currTime;
        }

    }

    /// Draw onscreen parts of the texture.
    void drawAlign(FluidBackend backend, Rectangle rectangle, Color tint = Color(0xff, 0xff, 0xff, 0xff)) {

        // Draw each visible chunk
        foreach (index; visibleChunks(rectangle.start, backend.windowSize)) {

            assert(chunks[index].texture.backend !is null);
            debug assert(backend == chunks[index].texture.backend,
                .format!"Backend mismatch %s != %s"(backend, chunks[index].texture.backend));

            const start = rectangle.start + chunkPosition(index);
            const size = chunks[index].texture.viewportSize;
            const rect = Rectangle(start.tupleof, size.tupleof);

            // Assign palette
            chunks[index].palette = palette;

            debug (Fluid_TextChunks) {

                if (index % 2) {
                    backend.drawRectangle(rect, color("#0002"));
                }
                else {
                    backend.drawRectangle(rect, color("#fff2"));
                }

            }

            debug (Fluid_TextUpdates) {

                const timeSinceLastUpdate = Clock.currTime - chunks[index].lastEdit;
                const secondsSinceLastUpdate = timeSinceLastUpdate.total!"msecs" / 1000f;

                if (0 <= secondsSinceLastUpdate && secondsSinceLastUpdate <= 1) {

                    const opacity = 1 - secondsSinceLastUpdate;

                    backend.drawRectangle(rect, color("#ffc307").setAlpha(opacity));

                }


            }

            backend.drawTextureAlign(chunks[index], rect, tint);

        }

    }

    /// Draw onscreen parts of the texture using the new backend.
    void drawAlign(CanvasIO canvasIO, Rectangle rectangle, Color tint = Color(0xff, 0xff, 0xff, 0xff)) {

        auto chosenChunks = visibleChunks(canvasIO, rectangle.start);

        // Draw each visible chunk
        foreach (index; chosenChunks) {
            chunks[index].image.palette = palette;
            const rect = chunkViewportRectangle(index, rectangle.start);

            debug (Fluid_TextChunks) {
                if (index % 2) {
                    canvasIO.drawRectangle(rect, color("#0002"));
                }
                else {
                    canvasIO.drawRectangle(rect, color("#fff2"));
                }
            }

            debug (Fluid_TextUpdates) {
                const timeSinceLastUpdate = Clock.currTime - chunks[index].lastEdit;
                const secondsSinceLastUpdate = timeSinceLastUpdate.total!"msecs" / 1000f;

                if (0 <= secondsSinceLastUpdate && secondsSinceLastUpdate <= 1) {
                    const opacity = 1 - secondsSinceLastUpdate;
                    canvasIO.drawRectangle(
                        rect,
                        color("#ffc307")
                            .setAlpha(opacity));
                }
            }
            chunks[index].image.drawHinted(rect, tint);
        }

    }


}

unittest {

    import std.file;
    import fluid.text_input;

    auto root = textInput();
    root.draw();
    root.io.clipboard = readText(__FILE__);
    root.paste();
    root.draw();

}

