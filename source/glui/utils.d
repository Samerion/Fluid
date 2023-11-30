///
module glui.utils;

import raylib;

import std.meta;
import std.functional;

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

        auto result = new Type(args);
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

// lmao
// AliasSeq!(AliasSeq!(T...)) won't work, this is a workaround
// too lazy to document, used to generate node constructors with variadic or optional arguments.
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

/// Get the current HiDPI scale. Returns Vector2(1, 1) if HiDPI is off.
Vector2 hidpiScale() @trusted {

    // HiDPI is on
    return IsWindowState(ConfigFlags.FLAG_WINDOW_HIGHDPI)
        ? GetWindowScaleDPI
        : Vector2.one;

}
