///
module fluid.theme.style;

import std.math;
import std.range;
import std.format;
import std.typecons;
import std.algorithm;

import fluid.node;
import fluid.backend;
import fluid.text.typeface;
import fluid.text.freetype;

public import fluid.theme : Theme, Selector, rule, Rule, when, WhenRule, children, ChildrenRule, Field, Breadcrumbs;
public import fluid.border;
public import fluid.theme.default_theme;
public import fluid.tree.types : color;

@safe:

/// Contains the style for a node.
struct Style {

    enum Themable;

    alias Side = .Side;

    // Text options
    @Themable {

        /// Main typeface to be used for text.
        ///
        /// Changing the typeface requires a resize.
        Typeface typeface;

        alias font = typeface;

        /// Size of the font in use, in pixels.
        ///
        /// Changing the size requires a resize.
        float fontSize = 14.pt;

        /// Text color.
        auto textColor = Color(0, 0, 0, 0);

    }

    // Background & content
    @Themable {

        /// Color of lines belonging to the node, especially important to separators and sliders.
        auto lineColor = Color(0, 0, 0, 0);

        /// Background color of the node.
        auto backgroundColor = Color(0, 0, 0, 0);

        /// Background color for selected text.
        auto selectionBackgroundColor = Color(0, 0, 0, 0);

    }

    // Spacing
    @Themable {

        /// Margin (outer margin) of the node. `[left, right, top, bottom]`.
        ///
        /// Updating margins requires a resize.
        ///
        /// See: `isSideArray`.
        float[4] margin = 0;

        /// Border size, placed between margin and padding. `[left, right, top, bottom]`.
        ///
        /// Updating border requires a resize.
        ///
        /// See: `isSideArray`
        float[4] border = 0;

        /// Padding (inner margin) of the node. `[left, right, top, bottom]`.
        ///
        /// Updating padding requires a resize.
        ///
        /// See: `isSideArray`
        float[4] padding = 0;

        /// Margin/gap between two neighboring elements; for container nodes that support it.
        ///
        /// Updating the gap requires a resize.
        float[2] gap = 0;

        /// Border style to use.
        ///
        /// Updating border requires a resize.
        FluidBorder borderStyle;

    }

    // Misc
    public {

        /// Apply tint to all node contents, including children.
        @Themable
        Color tint = Color(0xff, 0xff, 0xff, 0xff);

        /// Cursor icon to use while this node is hovered.
        ///
        /// Custom image cursors are not supported yet.
        @Themable
        FluidMouseCursor mouseCursor;

        /// Additional information for the node the style applies to.
        ///
        /// Ignored if mismatched.
        @Themable
        Node.Extra extra;

        /// Get or set node opacity. Value in range [0, 1] — 0 is fully transparent, 1 is fully opaque.
        float opacity() const {

            return tint.a / 255.0f;

        }

        /// ditto
        float opacity(float value) {

            tint.a = cast(ubyte) clamp(value * ubyte.max, ubyte.min, ubyte.max);

            return value;

        }

    }

    public {

        /// Breadcrumbs associated with this style. Used to keep track of tree-aware theme selectors, such as 
        /// `children`. Does not include breadcrumbs loaded by parent nodes.
        Breadcrumbs breadcrumbs;

    }

    private this(Typeface typeface) {

        this.typeface = typeface;

    }

    static Typeface defaultTypeface() {

        return FreetypeTypeface.defaultTypeface;

    }

    static Typeface loadTypeface(string file) {

        return new FreetypeTypeface(file);

    }

    alias loadFont = loadTypeface;

    bool opCast(T : bool)() const {

        return this !is Style(null);

    }

    bool opEquals(const Style other) const @trusted {

        // @safe: FluidBorder and Typeface are required to provide @safe opEquals.
        // D doesn't check for opEquals on interfaces, though.
        return this.tupleof == other.tupleof;

    }

    /// Set current DPI.
    void setDPI(Vector2 dpi) {

        getTypeface.setSize(dpi, fontSize);

    }

    /// Get current typeface, or fallback to default.
    Typeface getTypeface() {

        return either(typeface, defaultTypeface);

    }

    const(Typeface) getTypeface() const {

        return either(typeface, defaultTypeface);

    }

    /// Draw the background & border.
    void drawBackground(FluidBackend backend, Rectangle rect) const {

        backend.drawRectangle(rect, backgroundColor);

        // Add border if active
        if (borderStyle) {

            borderStyle.apply(backend, rect, border);

        }

    }

    /// Draw a line.
    void drawLine(FluidBackend backend, Vector2 start, Vector2 end) const {

        backend.drawLine(start, end, lineColor);

    }

    /// Get a side array holding both the regular margin and the border.
    float[4] fullMargin() const {

        return [
            margin.sideLeft + border.sideLeft,
            margin.sideRight + border.sideRight,
            margin.sideTop + border.sideTop,
            margin.sideBottom + border.sideBottom,
        ];

    }

    /// Remove padding from the vector representing size of a box.
    Vector2 contentBox(Vector2 size) const {

        return cropBox(size, padding);

    }

    /// Remove padding from the given rect.
    Rectangle contentBox(Rectangle rect) const {

        return cropBox(rect, padding);

    }

    /// Get a sum of margin, border size and padding.
    float[4] totalMargin() const {

        float[4] ret = margin[] + border[] + padding[];
        return ret;

    }

    /// Crop the given box by reducing its size on all sides.
    static Vector2 cropBox(Vector2 size, float[4] sides) {

        size.x = max(0, size.x - sides.sideLeft - sides.sideRight);
        size.y = max(0, size.y - sides.sideTop - sides.sideBottom);

        return size;

    }

    /// ditto
    static Rectangle cropBox(Rectangle rect, float[4] sides) {

        rect.x += sides.sideLeft;
        rect.y += sides.sideTop;

        const size = cropBox(Vector2(rect.w, rect.h), sides);
        rect.width = size.x;
        rect.height = size.y;

        return rect;

    }

}

unittest {

    import fluid.frame;

    auto io = new HeadlessBackend;
    auto myTheme = nullTheme.derive(
        rule!Frame(
            Rule.backgroundColor = color!"fff",
            Rule.tint = color!"aaaa",
        ),
    );
    auto root = vframe(
        layout!(1, "fill"),
        myTheme,
        vframe(
            layout!(1, "fill"),
            vframe(
                layout!(1, "fill"),
                vframe(
                    layout!(1, "fill"),
                )
            ),
        ),
    );

    root.io = io;
    root.draw();

    auto rect = Rectangle(0, 0, 800, 600);
    auto bg = color!"fff";

    // Background rectangles — all covering the same area, but with fading color and transparency
    io.assertRectangle(rect, bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(rect, bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(rect, bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(rect, bg = multiply(bg, color!"aaaa"));

}

unittest {

    import fluid.frame;

    auto io = new HeadlessBackend;
    auto myTheme = nullTheme.derive(
        rule!Frame(
            Rule.backgroundColor = color!"fff",
            Rule.tint = color!"aaaa",
            Rule.border.sideRight = 1,
            Rule.borderStyle = colorBorder(color!"f00"),
        )
    );
    auto root = vframe(
        layout!(1, "fill"),
        myTheme,
        vframe(
            layout!(1, "fill"),
            vframe(
                layout!(1, "fill"),
                vframe(
                    layout!(1, "fill"),
                )
            ),
        ),
    );

    root.io = io;
    root.draw();

    auto bg = color!"fff";

    // Background rectangles — reducing in size every pixel as the border gets added
    io.assertRectangle(Rectangle(0, 0, 800, 600), bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(Rectangle(0, 0, 799, 600), bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(Rectangle(0, 0, 798, 600), bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(Rectangle(0, 0, 797, 600), bg = multiply(bg, color!"aaaa"));

    auto border = color!"f00";

    // Border rectangles
    io.assertRectangle(Rectangle(799, 0, 1, 600), border = multiply(border, color!"aaaa"));
    io.assertRectangle(Rectangle(798, 0, 1, 600), border = multiply(border, color!"aaaa"));
    io.assertRectangle(Rectangle(797, 0, 1, 600), border = multiply(border, color!"aaaa"));
    io.assertRectangle(Rectangle(796, 0, 1, 600), border = multiply(border, color!"aaaa"));

}
