///
module fluid.utils;

import std.meta;
import std.traits;
import std.functional;

import fluid.types;


@safe:


alias simpleConstructor = nodeBuilder;
alias SimpleConstructor = NodeBuilder;
alias isSimpleConstructor = isNodeBuilder;

deprecated("Use NodeBuilder instead") {
    alias componentBuilder = nodeBuilder;
    alias ComponentBuilder = NodeBuilder;
    alias isComponentBuilder = isNodeBuilder;
}

// For saner testing and debugging.
version (unittest)
private extern(C) __gshared string[] rt_options = ["oncycle=ignore"];

/// Create a component builder for declarative usage.
///
/// Initial properties can be provided in the function provided in the second argument.
enum nodeBuilder(T, alias fun = "a") = NodeBuilder!(T, fun).init;

/// Create a simple template node constructor for declarative usage.
///
/// If the parent is a simple constructor, its initializer will be ran *after* this one. This is because the user
/// usually specifies the parent in templates, so it has more importance.
///
/// T must be a template accepting a single parameter — Parent type will be passed to it.
template nodeBuilder(alias T, alias Parent, alias fun = "a") {

    alias nodeBuilder = nodeBuilder!(T!(Parent.Type), (a) {

        alias initializer = unaryFun!fun;

        initializer(a);
        Parent.initialize(a);

    });

}

/// ditto
alias nodeBuilder(alias T, Parent, alias fun = "a") = nodeBuilder!(T!Parent, fun);

enum isNodeBuilder(T) = is(T : NodeBuilder!(A, a), A, alias a);

struct NodeBuilder(T, alias fun = "a") {

    import fluid.style;
    import fluid.structs;

    alias Type = T;

    deprecated("`NodeBuilder.initializer` is affected by a codegen bug in DMD, "
        ~ "and has been replaced with `initialize`. "
        ~ "Please update your code before Fluid 0.8.0")
    alias initializer = unaryFun!fun;

    void initialize(T node) {
        unaryFun!fun(node);
    }

    Type opCall(Args...)(Args args) {

        // Collect parameters
        enum paramCount = leadingParams!Args;

        // Construct the node
        auto result = new Type(args[paramCount..$]);

        // Run the initializer
        initialize(result);

        // Apply the parameters
        result.applyAll(args[0..paramCount]);

        return result;

    }

    /// Count node parameters present at the beginning of the given type list. This function is only available at
    /// compile-time.
    ///
    /// If a node parameter is passed *after* a non-parameter, it will not be included in the count, and will not be
    /// treated as one by ComponentBuilder.
    static int leadingParams(Args...)() {

        assert(__ctfe, "leadingParams is not available at runtime");

        if (__ctfe)
        foreach (i, Arg; Args) {

            // Found a non-parameter, return the index
            if (!isNodeParam!(Arg, T))
                return i;

        }

        // All arguments are parameters
        return Args.length;

    }

}

unittest {

    static class Foo {

        string value;

        this() { }

    }

    alias xfoo = nodeBuilder!Foo;
    assert(xfoo().value == "");

    alias yfoo = nodeBuilder!(Foo, (a) {
        a.value = "foo";
    });
    assert(yfoo().value == "foo");

    auto myFoo = new Foo;
    yfoo.initialize(myFoo);
    assert(myFoo.value == "foo");

    static class Bar(T) : T {

        int foo;

        this(int foo) {

            this.foo = foo;

        }

    }

    alias xbar(alias T) = nodeBuilder!(Bar, T);

    const barA = xbar!Foo(1);
    assert(barA.value == "");
    assert(barA.foo == 1);

    const barB = xbar!xfoo(2);
    assert(barB.value == "");
    assert(barB.foo == 2);

    const barC = xbar!yfoo(3);
    assert(barC.value == "foo");
    assert(barC.foo == 3);

}

/// Modify the subject by passing it to the `apply` method of each of the parameters.
///
/// This is made for `nodeBuilder` to apply node parameters on a node. The subject doesn't have to be a node.
///
/// Params:
///     subject    = Subject to modify.
///     parameters = Parameters to apply onto the subject;
/// Returns:
///     The subject after applying the modifications.
///     If subject is a class, this is the same object as passed.
Subject applyAll(Subject, Parameters...)(Subject subject, Parameters parameters) {

    foreach (param; parameters) {

        param.apply(subject);

    }

    return subject;

}

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
///     px = Input value in pixels.
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

/// Load a two dimensional vector from a string.
///
/// The string should either be a single float value, like `1.5`, or two, separated by an `x`
/// character: `1.5 x 1.2`. If there is only one value, it will be used for both axes.
///
/// Params:
///     source = String to parse.
/// Returns:
///     String to load from.
Vector2 toSizeVector2(string source) {

    import std.conv : to;
    import std.string : strip;
    import std.algorithm : findSplit;

    // Load the render scale from environment
    if (auto pair = source.findSplit("x")) {
        return Vector2(
            pair[0].strip.to!float,
            pair[2].strip.to!float
        );
    }
    else {
        const value = source.strip.to!float;
        return Vector2(value, value);
    }

}

unittest {

    assert("1.5".toSizeVector2 == Vector2(1.5, 1.5));
    assert("1.5x1.2".toSizeVector2 == Vector2(1.5, 1.2));
    assert("2.0 x 1.0".toSizeVector2 == Vector2(2.0, 1.0));
    assert(" 2.0x1.0 ".toSizeVector2 == Vector2(2.0, 1.0));

}

// Extremely useful Rectangle utilities

/// Get the top-left corner of a rectangle.
Vector2 start(Rectangle r) nothrow {
    return Vector2(r.x, r.y);
}

/// Get the bottom-right corner of a rectangle.
Vector2 end(Rectangle r) nothrow {
    return Vector2(r.x + r.w, r.y + r.h);
}

/// Get the center of a rectangle.
Vector2 center(Rectangle r) nothrow {
    return Vector2(r.x + r.w/2, r.y + r.h/2);
}

/// Get the size of a rectangle.
Vector2 size(Rectangle r) nothrow {
    return Vector2(r.w, r.h);
}

/// Get the area of a rectangle.
float area(Rectangle r) nothrow {
    return r.w * r.h;
}

/// Intersect two rectangles
Rectangle intersect(Rectangle one, Rectangle two) nothrow {

    import std.algorithm : min, max;

    Rectangle result;
    result.x = max(one.x, two.x);
    result.y = max(one.y, two.y);
    result.w = max(0, min(one.x + one.w, two.x + two.w) - result.x);
    result.h = max(0, min(one.y + one.h, two.y + two.h) - result.y);
    return result;

}

/// Create a point that is in the same position relative to the destination rectangle,
/// as is the input point relative to the source rectangle.
///
/// Relation is expressed is in term of a fraction or percentage. If the point is in the center
/// of the source rectangle, the returned point will be in the center of the destination
/// rectangle.
///
/// Params:
///     point       = Point to transform.
///     source      = Original viewport; source point is relative to this viewport.
///     destination = Viewport used as destination. Resulting point will be relative
///         to this viewport.
/// Returns:
///     A point located in the same place, relative to the other viewport.
Vector2 viewportTransform(Vector2 point, Rectangle source, Rectangle destination) {
    point = point - source.start;
    point = Vector2(
        point.x * destination.width  / source.width,
        point.y * destination.height / source.height,
    );
    return point + destination.start;
}

///
@("Viewport transform example works")
unittest {

    const source      = Rectangle(100, 100,  50,  50);
    const destination = Rectangle(100,   0, 100, 100);

    // Corners and center
    assert(source.start .viewportTransform(source, destination) == destination.start);
    assert(source.center.viewportTransform(source, destination) == destination.center);
    assert(source.end   .viewportTransform(source, destination) == destination.end);

    // Arbitrary positions
    assert(Vector2(125, 100).viewportTransform(source, destination) == Vector2( 150,    0));
    assert(Vector2(  0,   0).viewportTransform(source, destination) == Vector2(-100, -200));

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
