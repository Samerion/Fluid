/// Vendored from <https://github.com/schveiguy/raylib-d/blob/master/source/raylib/raylib_types.d>.
/// This module is used regardless of whether Raylib is used with Fluid or not, in order to stay compatible with its 
/// math API.
module raylib;

@safe:

// Color type, R8G8B8A8 (32bit)
struct Color
{
    ubyte r;
    ubyte g;
    ubyte b;
    ubyte a = 255;

    @safe @nogc nothrow:

    this(ubyte r, ubyte g, ubyte b, ubyte a = 255) {
        this.r = r;
        this.g = g;
        this.b = b;
        this.a = a;
    }

    this(ubyte[4] rgba) {
        this(rgba[0], rgba[1], rgba[2], rgba[3]);
    }

    this(ubyte[3] rgb) {
        this(rgb[0], rgb[1], rgb[2], 255);
    }
}
