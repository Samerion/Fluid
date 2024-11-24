///
module fluid.utils;

import std.meta;
import std.traits;
import std.functional;

import fluid.types;

public import fluid.node : nodeBuilder, isNodeBuilder, NodeBuilder, 
    simpleConstructor, SimpleConstructor, isSimpleConstructor;

@safe:

// For saner testing and debugging.
version (unittest)
private extern(C) __gshared string[] rt_options = ["oncycle=ignore"];

/// Get distance between two vectors.
float distance(Vector2 a, Vector2 b) {

    import std.math : sqrt;

    return sqrt(distance2(a, b));

}

/// Get distance between two vectors, squared.
float distance2(Vector2 a, Vector2 b) {

    return (a.x - b.x)^^2 + (a.y - b.y)^^2;

}

/// Convert points to pixels.
/// Params:
///     points = Input value in points.
/// Returns: Given value in pixels.
float pt(float points) {

    // 1 pt = 1/72 in
    // 1 px = 1/96 in
    // 96 px = 72 pt

    return points * 96 / 72;

}

/// Convert pixels to points.
/// Params:
///     points = Input value in pixels.
/// Returns: Given value in points.
float pxToPt(float px) {

    return px * 72 / 96;

}

unittest {

    import std.conv;

    assert(to!int(4.pt * 100) == 533);
    assert(to!int(5.33.pxToPt * 100) == 399);


}

/// Check if the rectangle contains a point.
bool contains(Rectangle rectangle, Vector2 point) {

    return rectangle.x <= point.x
        && point.x < rectangle.x + rectangle.width
        && rectangle.y <= point.y
        && point.y < rectangle.y + rectangle.height;

}

/// Check if the two rectangles overlap.
bool overlap(Rectangle a, Rectangle b) {

    const x = (start(b).x <= a.x && a.x <= end(b).x)
        ||    (start(a).x <= b.x && b.x <= end(a).x);
    const y = (start(b).y <= a.y && a.y <= end(b).y)
        ||    (start(a).y <= b.y && b.y <= end(a).y);

    return x && y;

}

// Extremely useful Rectangle utilities

/// Get the top-left corner of a rectangle.
Vector2 start(Rectangle r) {
    return Vector2(r.x, r.y);
}

/// Get the bottom-right corner of a rectangle.
Vector2 end(Rectangle r) {
    return Vector2(r.x + r.w, r.y + r.h);
}

/// Get the center of a rectangle.
Vector2 center(Rectangle r) {
    return Vector2(r.x + r.w/2, r.y + r.h/2);
}

/// Get the size of a rectangle.
Vector2 size(Rectangle r) {
    return Vector2(r.w, r.h);
}

/// Get names of static fields in the given object.
///
/// Ignores deprecated fields.
template StaticFieldNames(T) {

    import std.traits : hasStaticMember;
    import std.meta : Alias, Filter;

    // Prepare data
    alias Members = __traits(allMembers, T);

    template isStaticMember(string member) {

        enum isStaticMember =

            // Make sure this isn't an alias
            __traits(compiles,
                Alias!(__traits(getMember, T, member))
            )

            && !__traits(isDeprecated, __traits(getMember, T, member))

            // Find the member
            && hasStaticMember!(T, member);

    }

    // Result
    alias StaticFieldNames = Filter!(isStaticMember, Members);

}

/// Open given URL in a web browser.
///
/// Supports all major desktop operating systems. Does nothing if not supported on the given platform.
///
/// At the moment this simply wraps `std.process.browse`.
void openURL(scope const(char)[] url) nothrow {

    version (Posix) {
        import std.process;
        browse(url);
    }
    else version (Windows) {
        import std.process;
        browse(url);
    }

    // Do nothing on remaining platforms

}
