///
module fluid.utils;

import std.meta;
import std.traits;
import std.functional;

import fluid.backend;


@safe:


// For saner testing and debugging.
version (unittest)
private extern(C) __gshared string[] rt_options = ["oncycle=ignore"];

/// Create a simple node constructor for declarative usage.
///
/// Initial properties can be provided in the function provided in the second argument.
enum simpleConstructor(T, alias fun = "a") = SimpleConstructor!(T, fun).init;

/// Create a simple template node constructor for declarative usage.
///
/// If the parent is a simple constructor, its initializer will be ran *after* this one. This is because the user
/// usually specifies the parent in templates, so it has more importance.
///
/// T must be a template accepting a single parameter — Parent type will be passed to it.
template simpleConstructor(alias T, alias Parent, alias fun = "a") {

    alias simpleConstructor = simpleConstructor!(T!(Parent.Type), (a) {

        alias initializer = unaryFun!fun;

        initializer(a);
        Parent.initializer(a);

    });

}

/// ditto
alias simpleConstructor(alias T, Parent, alias fun = "a") = simpleConstructor!(T!Parent, fun);

enum isSimpleConstructor(T) = is(T : SimpleConstructor!(A, a), A, alias a);

struct SimpleConstructor(T, alias fun = "a") {

    import fluid.style;
    import fluid.structs;

    alias Type = T;
    alias initializer = unaryFun!fun;

    Type opCall(Args...)(Args args) {

        // Collect parameters
        enum paramCount = leadingParams!Args;

        // Construct the node
        auto result = new Type(args[paramCount..$]);

        // Run the initializer
        initializer(result);

        // Pass the parameters
        foreach (param; args[0..paramCount]) {

            param.apply(result);

        }

        return result;

    }

    /// Count node parameters present at the beginning of the given type list. This function is only available at
    /// compile-time.
    ///
    /// If a node parameter is passed *after* a non-parameter, it will not be included in the count, and will not be
    /// treated as one by simpleConstructor.
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

    alias xfoo = simpleConstructor!Foo;
    assert(xfoo().value == "");

    alias yfoo = simpleConstructor!(Foo, (a) {
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

    alias xbar(alias T) = simpleConstructor!(Bar, T);

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

/// Check if the rectangle contains a point.
bool contains(Rectangle rectangle, Vector2 point) {

    return rectangle.x <= point.x
        && point.x < rectangle.x + rectangle.width
        && rectangle.y <= point.y
        && point.y < rectangle.y + rectangle.height;

}

// Extremely useful Rectangle utilities

/// Get the top-left corner of a rectangle.
Vector2 start(Rectangle r) => Vector2(r.x, r.y);

/// Get the bottom-right corner of a rectangle.
Vector2 end(Rectangle r) => Vector2(r.x + r.w, r.y + r.h);

/// Get the center of a rectangle.
Vector2 center(Rectangle r) => Vector2(r.x + r.w/2, r.y + r.h/2);

/// Get the size of a rectangle.
Vector2 size(Rectangle r) => Vector2(r.w, r.h);

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
