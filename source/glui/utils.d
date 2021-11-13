///
module glui.utils;

import raylib;
import std.meta;

import glui.style;
import glui.structs;

@safe:

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

    static if (index == 0) alias BasicNodeParam = AliasSeq!(Layout, const Theme);
    static if (index == 1) alias BasicNodeParam = AliasSeq!(const Theme, Layout);
    static if (index == 2) alias BasicNodeParam = AliasSeq!(Layout);
    static if (index == 3) alias BasicNodeParam = AliasSeq!(const Theme);
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

/// Get the current HiDPI scale. Returns Vector2(1, 1) if HiDPI is off.
Vector2 hidpiScale() @trusted {

    return IsWindowState(ConfigFlags.FLAG_WINDOW_HIGHDPI)
        ? GetWindowScaleDPI
        : Vector2.one;

}
