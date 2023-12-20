///
module glui.utils;

import std.meta;
import std.functional;

import glui.backend;

@safe:

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

    alias Type = T;
    alias initializer = unaryFun!fun;

    Type opCall(Args...)(Args args) {

        import glui.style;
        import glui.structs;

        // Determine if an argument is a parameter
        enum isTheme(T) = is(T : const Theme);
        enum isLayout(T) = is(T : Layout);

        // Scan for parameters
        static if (Args.length >= 1) {

            alias FirstArg = Args[0];

            // Load the second argument with a fallback
            static if (Args.length >= 2)
                alias SecondArg = Args[1];
            else
                alias SecondArg = void;

            // Check if the first parameter is a parameter
            static if (isTheme!FirstArg) {

                enum arity = 1 + isLayout!SecondArg;

            }

            else static if (isLayout!FirstArg) {

                enum arity = 1 + isTheme!SecondArg;

            }

            else enum arity = 0;

        }

        else enum arity = 0;

        // Construct the node
        auto params = NodeParams(args[0..arity]);

        // Collect the parameters into NodeParams
        static if (__traits(compiles, new Type(params, args[arity..$]))) {

            auto result = new Type(params, args[arity..$]);

        }

        // Old-style, plain construction
        else {

            auto result = new Type(args);

        }

        initializer(result);
        return result;

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

deprecated("BasicNodeParams are deprecated in favor of simpleConstructor. Define constructors using NodeParams as the "
    ~ "first argument instead") {

    alias BasicNodeParamLength = Alias!5;
    template BasicNodeParam(int index) {

        import glui.style;
        import glui.structs;

        static if (index == 0) alias BasicNodeParam = AliasSeq!(Layout, const Theme);
        static if (index == 1) alias BasicNodeParam = AliasSeq!(const Theme, Layout);
        static if (index == 2) alias BasicNodeParam = AliasSeq!(Layout);
        static if (index == 3) alias BasicNodeParam = AliasSeq!(const Theme);
        static if (index == 4) alias BasicNodeParam = AliasSeq!();

    }

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
