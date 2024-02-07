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

/// Tags are optional "marks" left on nodes that are used to apply matching styles. Tags closely resemble
/// [HTML classes](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/class).
///
/// Tags have to be explicitly defined before usage, by creating an enum and marking it with the `@NodeTag` attribute.
/// Such tags can then be applied by passing them to the constructor.
enum NodeTag;

///
unittest {

    import fluid.label;

    @NodeTag
    enum Tags {
        myTag,
    }

    label(Tags.myTag, "Hello, World!");

}

enum isNodeTag(alias tag)
    = hasUDA!(tag, NodeTag)
    || hasUDA!(typeof(tag), NodeTag);

unittest {

    @NodeTag
    enum singleEnum;

    assert(isNodeTag!singleEnum);

    @NodeTag
    enum Tags { a, b, c }

    assert(isNodeTag!(Tags.a));
    assert(isNodeTag!(Tags.b));
    assert(isNodeTag!(Tags.c));

    enum NonTags { a, b, c }

    assert(!isNodeTag!(NonTags.a));
    assert(!isNodeTag!(NonTags.b));
    assert(!isNodeTag!(NonTags.c));

    enum SomeTags { a, b, @NodeTag tag }

    assert(!isNodeTag!(SomeTags.a));
    assert(!isNodeTag!(SomeTags.b));
    assert(isNodeTag!(SomeTags.tag));

}

/// Unique ID of a node tag.
immutable struct NodeTagID {

    /// Unique ID of the tag.
    size_t id;

    /// Tag name. Only emitted when debugging.
    debug string name;

    /// Get ID of an input action.
    this(alias tag)() immutable {

        enum Tag = NodeTagImpl!tag;

        this.id = cast(size_t) &Tag._id;
        debug this.name = fullyQualifiedName!tag;

    }

    bool opEqual(NodeTagID other) {

        return id == other.id;

    }

}

private struct NodeTagImpl(alias nodeTag)
if (isNodeTag!nodeTag) {

    alias tag = nodeTag;

    alias id this;

    /// Implementation is the same as input action IDs, see fluid.input.InputAction.
    /// For what's important, the _id field is not the ID; its pointer however, is.
    align(1)
    private static immutable bool _id;

    static NodeTagID id() {

        return NodeTagID!(typeof(this)());

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
