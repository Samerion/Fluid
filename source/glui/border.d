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
