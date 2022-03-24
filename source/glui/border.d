module glui.border;

import raylib;

import glui.style;


@safe:


/// Interface for borders
abstract class GluiBorder {

    /// Size of the border.
    uint[4] size;

    /// Apply the border, drawing it in the given box.
    abstract void apply(Rectangle borderBox) const;

    /// Get the rectangle for the given side of the border.
    protected Rectangle sideRect(Rectangle source, Style.Side side) const {

        final switch (side) {

            case Style.Side.left:
                return Rectangle(
                    source.x, source.y,
                    size.sideLeft, source.height,
                );

            case Style.Side.right:
                return Rectangle(
                    source.x + source.width - size.sideRight, source.y,
                    size.sideRight, source.height,
                );

            case Style.Side.top:
                return Rectangle(
                    source.x, source.y,
                    source.width, size.sideTop
                );

            case Style.Side.bottom:
                return Rectangle(
                    source.x, source.y + source.height - size.sideBottom,
                    source.width, size.sideBottom
                );

        }

    }

}




ColorBorder colorBorder(uint size, Color color) {

    return colorBorder([size], [color]);

}

ColorBorder colorBorder(size_t n)(uint[n] size, Color color) {

    return colorBorder(size, [color]);

}

ColorBorder colorBorder(size_t n)(uint size, Color[n] color) {

    return colorBorder([size], color);

}

ColorBorder colorBorder(size_t n, size_t m)(uint[n] size, Color[m] color) {

    auto result = new ColorBorder;

    result.size = normalizeSideArray!uint(size);
    result.color = normalizeSideArray!Color(color);

    return result;

}

class ColorBorder : GluiBorder {

    Color[4] color;

    override void apply(Rectangle borderBox) const @trusted {

        import std.traits;

        foreach (side; EnumMembers!(Style.Side)) {

            // Draw all the fragments
            DrawRectangleRec(sideRect(borderBox, side), color[side]);

        }

    }

}
