///
module fluid.structs;

import std.conv;
import std.traits;

import fluid.node;


@safe:


/// Check if the given type implements node parameter interface.
///
/// Node parameters passed at the beginning of a simpleConstructor will not be passed to the node constructor. Instead,
/// their `apply` function will be called on the node after the node has been created. This can be used to initialize
/// properties at the time of creation. A basic implementation of the interface looks as follows:
///
/// ---
/// struct MyParameter {
///     void apply(Node node) { }
/// }
/// ---
///
/// Params:
///     T = Type to check
//      NodeType = Node to implement.
enum isNodeParam(T, NodeType = Node)
    = __traits(compiles, T.init.apply(NodeType.init));


enum NodeAlign {

    start, center, end, fill

}

/// Create a new layout
/// Params:
///     expand = Numerator of the fraction of space this node should occupy in the parent.
///     align_ = Align of the node (horizontal and vertical).
///     alignX = Horizontal align of the node.
///     alignY = Vertical align of the node.
Layout layout(uint expand, NodeAlign alignX, NodeAlign alignY) pure {

    return Layout(expand, [alignX, alignY]);

}

/// Ditto
Layout layout(uint expand, NodeAlign align_) pure {

    return Layout(expand, align_);

}

/// Ditto
Layout layout(NodeAlign alignX, NodeAlign alignY) pure {

    return Layout(0, [alignX, alignY]);

}

/// Ditto
Layout layout(NodeAlign align_) pure {

    return Layout(0, align_);

}

/// Ditto
Layout layout(uint expand) pure {

    return Layout(expand);

}

/// CTFE version of the layout constructor, allows using strings instead of enum members, to avoid boilerplate.
Layout layout(uint expand, string alignX, string alignY)() pure {

    enum valueX = alignX.to!NodeAlign;
    enum valueY = alignY.to!NodeAlign;

    return Layout(expand, [valueX, valueY]);

}

/// Ditto
Layout layout(uint expand, string align_)() pure {

    enum valueXY = align_.to!NodeAlign;

    return Layout(expand, valueXY);

}

/// Ditto
Layout layout(string alignX, string alignY)() pure {

    enum valueX = alignX.to!NodeAlign;
    enum valueY = alignY.to!NodeAlign;

    return Layout(0, [valueX, valueY]);

}

/// Ditto
Layout layout(string align_)() pure {

    enum valueXY = align_.to!NodeAlign;

    return Layout(0, valueXY);

}

/// Ditto
Layout layout(uint expand)() pure {

    return Layout(expand);

}

unittest {

    assert(layout!1 == layout(1));
    assert(layout!("fill") == layout(NodeAlign.fill, NodeAlign.fill));
    assert(layout!("fill", "fill") == layout(NodeAlign.fill));

    assert(!__traits(compiles, layout!"expand"));
    assert(!__traits(compiles, layout!("expand", "noexpand")));
    assert(!__traits(compiles, layout!(1, "whatever")));
    assert(!__traits(compiles, layout!(2, "foo", "bar")));

}

/// Node parameter for setting the node layout.
struct Layout {

    /// Fraction of available space this node should occupy in the node direction.
    ///
    /// If set to `0`, the node doesn't have a strict size limit and has size based on content.
    uint expand;

    /// Align the content box to a side of the occupied space.
    NodeAlign[2] nodeAlign;

    /// Apply this layout to the given node. Implements the node parameter.
    void apply(Node node) {

        node.layout = this;

    }

    string toString() const {

        import std.format;

        const equalAlign = nodeAlign[0] == nodeAlign[1];
        const startAlign = equalAlign && nodeAlign[0] == NodeAlign.start;

        if (expand) {

            if (startAlign) return format!".layout!%s"(expand);
            else if (equalAlign) return format!".layout!(%s, %s)"(expand, nodeAlign[0]);
            else return format!".layout!(%s, %s, %s)"(expand, nodeAlign[0], nodeAlign[1]);

        }

        else {

            if (startAlign) return format!"Layout()";
            else if (equalAlign) return format!".layout!%s"(nodeAlign[0]);
            else return format!".layout!(%s, %s)"(nodeAlign[0], nodeAlign[1]);

        }

    }

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

    auto myLabel = label(
        .tags!(Tags.myTag),
        "Hello, World!"
    );

    assert(myLabel.tags == .tags!(Tags.myTag));

}

/// Check if the given item is a node tag.
enum isNodeTag(alias tag)
    = hasUDA!(tag, NodeTag)
    || hasUDA!(typeof(tag), NodeTag);

/// Specify tags for the next node to add.
Tags tags(input...)() {

    auto result = new TagID[input.length];

    static foreach (i, tag; input) {

        result[i] = tagID!tag;

    }

    return Tags(result);

}

/// Node parameter assigning a new set of tags to a node.
struct Tags {

    TagID[] tags;

    void apply(Node node) {

        node.tags = this;

    }

}

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

TagID tagID(alias tag)() {

    enum Tag = TagIDImpl!tag();

    debug
        return TagID(cast(long) &Tag._id, fullyQualifiedName!tag);
    else
        return TagID(cast(long) &Tag._id);

}

/// Unique ID of a node tag.
struct TagID {

    /// Unique ID of the tag.
    long id;

    /// Tag name. Only emitted when debugging.
    debug string name;

    bool opEqual(TagID other) {

        return id == other.id;

    }

}

private struct TagIDImpl(alias nodeTag)
if (isNodeTag!nodeTag) {

    alias tag = nodeTag;

    /// Implementation is the same as input action IDs, see fluid.input.InputAction.
    /// For what's important, the _id field is not the ID; its pointer however, is.
    align(1)
    private static immutable bool _id;

}
