/// This module defines basic types from Raylib with local modifications to make them easier to use.
///
/// Vendored from <https://github.com/schveiguy/raylib-d/blob/master/source/raylib/raylib_types.d>.
/// This module is used regardless of whether Raylib is used with Fluid or not, in order to stay compatible with its 
/// math API.
///
/// License: [z-lib](https://github.com/schveiguy/raylib-d/blob/master/LICENSE)
module raylib.raylib_types;

public import raylib : Color;

// Vector2 type
struct Vector2
{
    float x = 0.0f;
    float y = 0.0f;
    
    enum zero = Vector2(0.0f, 0.0f);
    enum one = Vector2(1.0f, 1.0f);

    @safe @nogc nothrow:

    inout Vector2 opUnary(string op)() if (op == "+" || op == "-") {
        return Vector2(
            mixin(op, "x"),
            mixin(op, "y"),
        );
    }

    inout Vector2 opBinary(string op)(inout Vector2 rhs) if (op == "+" || op == "-") {
        return Vector2(
            mixin("x", op, "rhs.x"),
            mixin("y", op, "rhs.y"),
        );
    }

    ref Vector2 opOpAssign(string op)(inout Vector2 rhs) if (op == "+" || op == "-") {
        mixin("x", op, "=rhs.x;");
        mixin("y", op, "=rhs.y;");
        return this;
    }

    inout Vector2 opBinary(string op)(inout float rhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {
        return Vector2(
            mixin("x", op, "rhs"),
            mixin("y", op, "rhs"),
        );
    }

    inout Vector2 opBinaryRight(string op)(inout float lhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {
        return Vector2(
            mixin("lhs", op, "x"),
            mixin("lhs", op, "y"),
        );
    }

    ref Vector2 opOpAssign(string op)(inout float rhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {
        mixin("x", op, "=rhs;");
        mixin("y", op, "=rhs;");
        return this;
    }
}

// Vector3 type
struct Vector3
{
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;

    enum zero = Vector3(0.0f, 0.0f, 0.0f);
    enum one = Vector3(1.0f, 1.0f, 1.0f);

    @safe @nogc nothrow:

    inout Vector3 opUnary(string op)() if (op == "+" || op == "-") {
        return Vector3(
            mixin(op, "x"),
            mixin(op, "y"),
            mixin(op, "z"),
        );
    }

    inout Vector3 opBinary(string op)(inout Vector3 rhs) if (op == "+" || op == "-") {
        return Vector3(
            mixin("x", op, "rhs.x"),
            mixin("y", op, "rhs.y"),
            mixin("z", op, "rhs.z"),
        );
    }

    ref Vector3 opOpAssign(string op)(inout Vector3 rhs) if (op == "+" || op == "-") {
        mixin("x", op, "=rhs.x;");
        mixin("y", op, "=rhs.y;");
        mixin("z", op, "=rhs.z;");
        return this;
    }

    inout Vector3 opBinary(string op)(inout float rhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {
        return Vector3(
            mixin("x", op, "rhs"),
            mixin("y", op, "rhs"),
            mixin("z", op, "rhs"),
        );
    }

    inout Vector3 opBinaryRight(string op)(inout float lhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {
        return Vector3(
            mixin("lhs", op, "x"),
            mixin("lhs", op, "y"),
            mixin("lhs", op, "z"),
        );
    }

    ref Vector3 opOpAssign(string op)(inout float rhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {
        mixin("x", op, "=rhs;");
        mixin("y", op, "=rhs;");
        mixin("z", op, "=rhs;");
        return this;
    }
}

// Vector4 type
struct Vector4
{
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float w = 0.0f;

    enum zero = Vector4(0.0f, 0.0f, 0.0f, 0.0f);
    enum one = Vector4(1.0f, 1.0f, 1.0f, 1.0f);

    @safe @nogc nothrow:

    inout Vector4 opUnary(string op)() if (op == "+" || op == "-") {
        return Vector4(
            mixin(op, "x"),
            mixin(op, "y"),
            mixin(op, "z"),
            mixin(op, "w"),
        );
    }

    inout Vector4 opBinary(string op)(inout Vector4 rhs) if (op == "+" || op == "-") {
        return Vector4(
            mixin("x", op, "rhs.x"),
            mixin("y", op, "rhs.y"),
            mixin("z", op, "rhs.z"),
            mixin("w", op, "rhs.w"),
        );
    }

    ref Vector4 opOpAssign(string op)(inout Vector4 rhs) if (op == "+" || op == "-") {
        mixin("x", op, "=rhs.x;");
        mixin("y", op, "=rhs.y;");
        mixin("z", op, "=rhs.z;");
        mixin("w", op, "=rhs.w;");
        return this;
    }

    inout Vector4 opBinary(string op)(inout float rhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {
        return Vector4(
            mixin("x", op, "rhs"),
            mixin("y", op, "rhs"),
            mixin("z", op, "rhs"),
            mixin("w", op, "rhs"),
        );
    }

    inout Vector4 opBinaryRight(string op)(inout float lhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {
        return Vector4(
            mixin("lhs", op, "x"),
            mixin("lhs", op, "y"),
            mixin("lhs", op, "z"),
            mixin("lhs", op, "w"),
        );
    }

    ref Vector4 opOpAssign(string op)(inout float rhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {
        mixin("x", op, "=rhs;");
        mixin("y", op, "=rhs;");
        mixin("z", op, "=rhs;");
        mixin("w", op, "=rhs;");
        return this;
    }
}

// Quaternion type, same as Vector4
alias Quaternion = Vector4;

// Matrix type (OpenGL style 4x4 - right handed, column major)
struct Matrix
{
    float m0 = 0.0f;
    float m4 = 0.0f;
    float m8 = 0.0f;
    float m12 = 0.0f;
    float m1 = 0.0f;
    float m5 = 0.0f;
    float m9 = 0.0f;
    float m13 = 0.0f;
    float m2 = 0.0f;
    float m6 = 0.0f;
    float m10 = 0.0f;
    float m14 = 0.0f;
    float m3 = 0.0f;
    float m7 = 0.0f;
    float m11 = 0.0f;
    float m15 = 0.0f;
}

// Rectangle type
struct Rectangle
{
    float x;
    float y;
    float width;
    float height;
    alias w = width;
    alias h = height;

    @safe @nogc nothrow:

    void opOpAssign(string op)(Vector2 offset) if (op == "+" || op == "-") {
        mixin("this.x ", op, "= offset.x;");
        mixin("this.y ", op, "= offset.y;");
    }

    Rectangle opBinary(string op)(Vector2 offset) const if(op=="+" || op=="-") {
        Rectangle result = this;
        result.opOpAssign!op(offset);
        return result;
    }
}

enum Colors
{
    // Some Basic Colors
    // NOTE: Custom raylib color palette for amazing visuals on WHITE background
    LIGHTGRAY = Color(200, 200, 200, 255), // Light Gray
    GRAY = Color(130, 130, 130, 255), // Gray
    DARKGRAY = Color(80, 80, 80, 255), // Dark Gray
    YELLOW = Color(253, 249, 0, 255), // Yellow
    GOLD = Color(255, 203, 0, 255), // Gold
    ORANGE = Color(255, 161, 0, 255), // Orange
    PINK = Color(255, 109, 194, 255), // Pink
    RED = Color(230, 41, 55, 255), // Red
    MAROON = Color(190, 33, 55, 255), // Maroon
    GREEN = Color(0, 228, 48, 255), // Green
    LIME = Color(0, 158, 47, 255), // Lime
    DARKGREEN = Color(0, 117, 44, 255), // Dark Green
    SKYBLUE = Color(102, 191, 255, 255), // Sky Blue
    BLUE = Color(0, 121, 241, 255), // Blue
    DARKBLUE = Color(0, 82, 172, 255), // Dark Blue
    PURPLE = Color(200, 122, 255, 255), // Purple
    VIOLET = Color(135, 60, 190, 255), // Violet
    DARKPURPLE = Color(112, 31, 126, 255), // Dark Purple
    BEIGE = Color(211, 176, 131, 255), // Beige
    BROWN = Color(127, 106, 79, 255), // Brown
    DARKBROWN = Color(76, 63, 47, 255), // Dark Brown

    WHITE = Color(255, 255, 255, 255), // White
    BLACK = Color(0, 0, 0, 255), // Black
    BLANK = Color(0, 0, 0, 0), // Blank (Transparent)
    MAGENTA = Color(255, 0, 255, 255), // Magenta
    RAYWHITE = Color(245, 245, 245, 255), // My own White (raylib logo)
}
