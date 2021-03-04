///
module glui.utils;

import raylib;
import std.meta;

import glui.style;
import glui.structs;

/// Raylib functions not included in raylib-d
extern (C) @nogc nothrow {

    void SetMouseCursor(MouseCursor cursor);

    enum MouseCursor {
        MOUSE_CURSOR_DEFAULT,
        MOUSE_CURSOR_ARROW,
        MOUSE_CURSOR_IBEAM,
        MOUSE_CURSOR_CROSSHAIR,
        MOUSE_CURSOR_POINTING_HAND,
        MOUSE_CURSOR_RESIZE_EW,         // The horizontal resize/move arrow shape
        MOUSE_CURSOR_RESIZE_NS,         // The vertical resize/move arrow shape
        MOUSE_CURSOR_RESIZE_NWSE,       // The top-left to bottom-right diagonal resize/move arrow shape
        MOUSE_CURSOR_RESIZE_NESW,       // The top-right to bottom-left diagonal resize/move arrow shape
        MOUSE_CURSOR_RESIZE_ALL,        // The omni-directional resize/move cursor shape
        MOUSE_CURSOR_NOT_ALLOWED,       // The operation-not-allowed shape
    }

}

/// Create a function to easily construct nodes.
template simpleConstructor(T) {

    T simpleConstructor(Args...)(Args args) {

        return new T(args);

    }

}

// lmao
// AliasSeq!(AliasSeq!(T...)) won't work, this is a workaround
// too lazy to document, used to generate node constructors with variadic or optional arguments.
alias BasicNodeParamLength = Alias!5;
template BasicNodeParam(int index) {

    static if (index == 0) alias BasicNodeParam = AliasSeq!(Layout, Theme);
    static if (index == 1) alias BasicNodeParam = AliasSeq!(Theme, Layout);
    static if (index == 2) alias BasicNodeParam = AliasSeq!(Layout);
    static if (index == 3) alias BasicNodeParam = AliasSeq!(Theme);
    static if (index == 4) alias BasicNodeParam = AliasSeq!();

}

/// Check if the rectangle contains a point.
bool contains(Rectangle rectangle, Vector2 point) {

    return rectangle.x <= point.x
        && point.x < rectangle.x + rectangle.width
        && rectangle.y <= point.y
        && point.y < rectangle.y + rectangle.height;

}

/// Get names of static fields in the given object.
template StaticFieldNames(T) {

    import std.traits : hasStaticMember;
    import std.meta : Alias, Filter;

    // Prepare data
    alias Members = __traits(allMembers, T);

    // Check if the said member is static
    enum isStaticMember(alias member) =

        // Make sure this isn't an alias
        __traits(compiles,
            Alias!(__traits(getMember, T, member))
        )

        // Find the member
        && hasStaticMember!(T, member);

    // Result
    alias StaticFieldNames = Filter!(isStaticMember, Members);

}
