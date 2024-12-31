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
    yfoo.initializer(myFoo);
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
