module glui.border;

import glui.style;
import glui.backend;


@safe:


/// Interface for borders
interface GluiBorder {

    /// Apply the border, drawing it in the given box.
    abstract void apply(GluiBackend backend, Rectangle borderBox, uint[4] size) const;

    /// Get the rectangle for the given side of the border.
    final Rectangle sideRect(Rectangle source, uint[4] size, Style.Side side) const {

        final switch (side) {

            // Left side
            case Style.Side.left:
                return Rectangle(
                    source.x,
                    source.y + size.sideTop,
                    size.sideLeft,
                    source.height - size.sideTop - size.sideBottom,
                );

            // Right side
            case Style.Side.right:
                return Rectangle(
                    source.x + source.width - size.sideRight,
                    source.y + size.sideTop,
                    size.sideRight,
                    source.height - size.sideTop - size.sideBottom,
                );

            // Top side
            case Style.Side.top:
                return Rectangle(
                    source.x + size.sideLeft,
                    source.y,
                    source.width - size.sideLeft - size.sideRight,
                    size.sideTop
                );

            // Bottom side
            case Style.Side.bottom:
                return Rectangle(
                    source.x + size.sideLeft,
                    source.y + source.height - size.sideBottom,
                    source.width - size.sideLeft - size.sideRight,
                    size.sideBottom
                );

        }

    }

    /// Get square for corner next counter-clockwise to the given side.
    /// Note: returned rectangles may have negative size; rect start position will always point to the corner itself.
    final Rectangle cornerRect(Rectangle source, uint[4] size, Style.Side side) const {

        final switch (side) {

            case Style.Side.left:
                return Rectangle(
                    source.x,
                    source.y + source.height,
                    size.sideLeft,
                    -cast(float) size.sideBottom,
                );

            case Style.Side.right:
                return Rectangle(
                    source.x + source.width,
                    source.y,
                    -cast(float) size.sideRight,
                    size.sideTop,
                );

            case Style.Side.top:
                return Rectangle(
                    source.x,
                    source.y,
                    size.sideLeft,
                    size.sideTop,
                );

            case Style.Side.bottom:
                return Rectangle(
                    source.x + source.width,
                    source.y + source.height,
                    -cast(float) size.sideRight,
                    -cast(float) size.sideBottom,
                );

        }

    }

}



ColorBorder colorBorder(Color color) {

    return colorBorder([color]);

}

ColorBorder colorBorder(size_t n)(Color[n] color) {

    auto result = new ColorBorder;
    result.color = normalizeSideArray!Color(color);
    return result;

}

class ColorBorder : GluiBorder {

    Color[4] color;

    void apply(GluiBackend io, Rectangle borderBox, uint[4] size) const @trusted {

        // For each side
        foreach (sideIndex; 0..4) {

            const side = cast(Style.Side) sideIndex;
            const nextSide = cast(Style.Side) ((sideIndex + 1) % 4);

            // Draw all the fragments
            io.drawRectangle(sideRect(borderBox, size, side), color[side]);

            // Draw triangles in the corner
            foreach (shift; 0..2) {

                // Get the corner
                const cornerSide = shiftSide(side, shift);

                // Get corner parameters
                const corner = cornerRect(borderBox, size, cornerSide);
                const cornerStart = Vector2(corner.x, corner.y);
                const cornerSize = Vector2(corner.w, corner.h);
                const cornerEnd = side < 2
                    ? Vector2(0, corner.h)
                    : Vector2(corner.w, 0);

                // Draw the first triangle
                if (!shift)
                io.drawTriangle(
                    cornerStart,
                    cornerStart + cornerSize,
                    cornerStart + cornerEnd,
                    color[side],
                );

                // Draw the second one
                else
                io.drawTriangle(
                    cornerStart,
                    cornerStart + cornerEnd,
                    cornerStart + cornerSize,
                    color[side],
                );

            }

        }

    }

}

unittest {

    import glui;
    import std.format;
    import std.algorithm;

    const viewportSize = Vector2(100, 100);

    auto io = new HeadlessBackend(viewportSize);
    auto root = vframe(
        layout!(1, "fill"),
    );

    root.io = io;

    // First frame: Solid border on one side only
    root.theme = Theme.init.makeTheme!q{
        GluiFrame.styleAdd!q{
            border.sideBottom = 4;
            borderStyle = colorBorder(color!"018b8d");
        };
    };
    root.draw();

    assert(
        io.rectangles.find!(a => a.isClose(0, 100 - 4, 100, 4))
            .front.color == color!"018b8d",
        "Border must be present underneath the rectangle"
    );

    enum colorCode = q{ [color!"018b8d", color!"8d7006", color!"038d23", color!"6b048d"] };

    Color[4] borderColor = mixin(colorCode);

    // Second frame: Border on all sides
    // TODO optimize monochrome borders, and test them as well
    io.nextFrame;
    root.theme = Theme.init.makeTheme!(colorCode.format!q{
        GluiFrame.styleAdd!q{
            border = 4;
            borderStyle = colorBorder(%s);
        };
    });
    root.reloadStyles();
    root.draw();

    // Rectangles
    io.assertRectangle(Rectangle(0, 4, 4, 92), borderColor.sideLeft);
    io.assertRectangle(Rectangle(96, 4, 4, 92), borderColor.sideRight);
    io.assertRectangle(Rectangle(4, 0, 92, 4), borderColor.sideTop);
    io.assertRectangle(Rectangle(4, 96, 92, 4), borderColor.sideBottom);

    // Triangles
    io.assertTriangle(Vector2(0, 100), Vector2(4, 96), Vector2(0, 96), borderColor.sideLeft);
    io.assertTriangle(Vector2(0, 0), Vector2(0, 4), Vector2(4, 4), borderColor.sideLeft);
    io.assertTriangle(Vector2(100, 0), Vector2(96, 4), Vector2(100, 4), borderColor.sideRight);
    io.assertTriangle(Vector2(100, 100), Vector2(100, 96), Vector2(96, 96), borderColor.sideRight);
    io.assertTriangle(Vector2(0, 0), Vector2(4, 4), Vector2(4, 0), borderColor.sideTop);
    io.assertTriangle(Vector2(100, 0), Vector2(96, 0), Vector2(96, 4), borderColor.sideTop);
    io.assertTriangle(Vector2(100, 100), Vector2(96, 96), Vector2(96, 100), borderColor.sideBottom);
    io.assertTriangle(Vector2(0, 100), Vector2(4, 100), Vector2(4, 96), borderColor.sideBottom);

}
