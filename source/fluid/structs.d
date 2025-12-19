///
module fluid.structs;

import std.conv;
import std.traits;

import fluid.node;
import fluid.types;


@safe:


/// Check if the given type implements node parameter interface.
///
/// Node parameters passed at the beginning of a [nodeBuilder][fluid.utils.nodeBuilder] will not
/// be passed to the node constructor. Instead, their `apply` function will be called on the node
/// after the node has been created. This can be used to initialize properties at the time of
/// creation. A basic implementation of the interface looks as follows:
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

    start, center, end, fill,

    centre = center

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

/// Place a rectangle inside another based on its specified alignment. This function considers
/// `NodeAlign.fill` to be equivalent to `NodeAlign.start`.
///
/// This function may commonly be used with `Layout.nodeAlign`.
///
/// Params:
///     alignment = Alignment to use for the child rectangle.
///     space     = Rectangle denoting available space (parent).
///     size      = Size of the rectangle to place (child).
/// Returns:
///     position = Position assigned to the child rectangle.
Vector2 alignRectangle(NodeAlign[2] alignment, Rectangle space, Vector2 size) {

    float impl(NodeAlign align_, lazy float spaceLeft) {
        with (NodeAlign)
        final switch (align_) {
            case start, fill: return 0;
            case center:      return spaceLeft / 2;
            case end:         return spaceLeft;
        }
    }

    return Vector2(
        space.x + impl(alignment[0], space.width  - size.x),
        space.y + impl(alignment[1], space.height - size.y),
    );

}

/// Tags are optional "marks" left on nodes that are used to apply matching styles. Tags closely resemble
/// [HTML classes](https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/class).
///
/// Tags have to be explicitly defined before usage by creating an enum and marking it with the `@NodeTag` attribute.
/// Such tags can then be applied by passing them to the constructor.
enum NodeTag;

///
unittest {

    import fluid.label;

    @NodeTag
    enum Tags {
        myTag,
    }

    static assert(isNodeTag!(Tags.myTag));

    auto myLabel = label(
        .tags!(Tags.myTag),
        "Hello, World!"
    );

    assert(myLabel.tags == .tags!(Tags.myTag));

}

/// Check if the given item is a node tag.
template isNodeTag(alias tag) {

    // @NodeTag enum Tag;
    // enum Tag { @NodeTag tag }
    enum isDirectTag
        = isSomeEnum!tag
        && hasUDA!(tag, NodeTag);

    // @NodeTag enum Enum { tag }
    static if (isType!tag)
        enum isTagMember = false;
    else
        enum isTagMember
            = is(typeof(tag)== enum)
            && hasUDA!(typeof(tag), NodeTag);

    enum isNodeTag = isDirectTag || isTagMember;

}

/// Test if the given symbol is an enum, or an enum member.
enum isSomeEnum(alias tag)
    = is(tag == enum)
    || is(__traits(parent, tag) == enum);

/// Specify tags for the next node to add.
TagList tags(input...)() {

    return TagList.init.add!input;

}

/// Node parameter assigning a new set of tags to a node.
struct TagList {

    import std.range;
    import std.algorithm;

    /// A *sorted* array of tags.
    private SortedRange!(TagID[]) range;

    /// Check if the range is empty.
    bool empty() {

        return range.empty;

    }

    /// Count all tags.
    size_t length() {

        return range.length;

    }

    /// Get a list of all tags in the list.
    const(TagID)[] get() {

        return range.release;

    }

    /// Create a new set of tags expanded by the given set of tags.
    TagList add(input...)() {

        const originalLength = this.range.length;

        TagID[input.length] newTags;

        // Load the tags
        static foreach (i, tag; input) {

            newTags[i] = tagID!tag;

        }

        // Allocate output range
        auto result = new TagID[originalLength + input.length];
        auto lhs = result[0..originalLength] = this.range.release;

        // Sort the result
        completeSort(assumeSorted(lhs), newTags[]);

        // Add the remaining tags
        result[originalLength..$] = newTags;

        return TagList(assumeSorted(result));

    }

    /// Remove given tags from the list.
    TagList remove(input...)() {

        TagID[input.length] targetTags;

        // Load the tags
        static foreach (i, tag; input) {

            targetTags[i] = tagID!tag;

        }

        // Sort them
        sort(targetTags[]);

        return TagList(
            setDifference(this.range, targetTags[])
                .array
                .assumeSorted
        );

    }

    unittest {

        @NodeTag
        enum Foo { a, b, c, d }

        auto myTags = tags!(Foo.a, Foo.b, Foo.c);

        assert(myTags.remove!(Foo.b, Foo.a) == tags!(Foo.c));
        assert(myTags.remove!(Foo.d) == myTags);
        assert(myTags.remove!() == myTags);
        assert(myTags.remove!(Foo.a, Foo.b, Foo.c) == tags!());
        assert(myTags.remove!(Foo.a, Foo.b, Foo.c, Foo.d) == tags!());

    }

    /// Get the intesection of the two tag lists.
    /// Returns: A range with tags that are present in both of the lists.
    auto intersect(TagList tags) {

        return setIntersection(this.range, tags.range);

    }

    /// Assign this list of tags to the given node.
    void apply(Node node) {

        node.tags = this;

    }

    string toString() {

        // Prevent writeln from clearing the range
        return text(range.release);

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

unittest {

    import std.range;
    import std.algorithm;

    @NodeTag
    enum MyTags {
        tag1, tag2
    }

    auto tags1 = tags!(MyTags.tag1, MyTags.tag2);
    auto tags2 = tags!(MyTags.tag2, MyTags.tag1);

    assert(tags1.intersect(tags2).walkLength == 2);
    assert(tags2.intersect(tags1).walkLength == 2);
    assert(tags1 == tags2);

    auto tags3 = tags!(MyTags.tag1);
    auto tags4 = tags!(MyTags.tag2);

    assert(tags1.intersect(tags3).equal(tagID!(MyTags.tag1).only));
    assert(tags1.intersect(tags4).equal(tagID!(MyTags.tag2).only));
    assert(tags3.intersect(tags4).empty);

}

TagID tagID(alias tag)()
out (r; r.id, "Invalid ID returned for tag " ~ tag.stringof)
do {

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

    invariant(id, "Tag ID must not be 0.");

    /// Tag name. Only emitted when debugging.
    debug string name;

    bool opEqual(TagID other) {

        return id == other.id;

    }

    long opCmp(TagID other) const {

        return id - other.id;

    }

}

private struct TagIDImpl(alias nodeTag)
if (isNodeTag!nodeTag) {

    alias tag = nodeTag;

    /// Implementation is the same as input action IDs, see fluid.input.InputAction.
    /// For what's important, the _id field is not the ID; its pointer however, is.
    private static immutable bool _id;

}

@("Members of anonymous enums cannot be NodeTags.")
unittest {

    class A {
        @NodeTag enum { foo }
    }
    class B : A {
        @NodeTag enum { bar }
    }

    assert(!__traits(compiles, tagID!(B.foo)));
    assert(!__traits(compiles, tagID!(B.bar)));

}

/// This node property will disable mouse input on the given node.
///
/// Params:
///     value = If set to false, the effect is reversed and mouse input is instead enabled.
auto ignoreMouse(bool value = true) {

    static struct IgnoreMouse {

        bool value;

        void apply(Node node) {

            node.ignoreMouse = value;

        }

    }

    return IgnoreMouse(value);

}

///
unittest {

    import fluid.label;
    import fluid.button;

    // Prevents the label from blocking the button
    vframeButton(
        label(.ignoreMouse, "Click me!"),
        delegate { }
    );

}

@("ignoreMouse property sets Node.ignoreMouse to true")
unittest {

    import fluid.space;

    assert(vspace().ignoreMouse == false);
    assert(vspace(.ignoreMouse).ignoreMouse == true);
    assert(vspace(.ignoreMouse(false)).ignoreMouse == false);
    assert(vspace(.ignoreMouse(true)).ignoreMouse == true);

}

/// This node property will make the subject hidden, setting the `isHidden` field to true.
///
/// Params:
///     value = If set to false, the effect is reversed and the node is set to be visible instead.
/// See_Also: `Node.isHidden`
auto hidden(bool value = true) {

    static struct Hidden {

        bool value;

        void apply(Node node) {

            node.isHidden = value;

        }

    }

    return Hidden(value);

}

///
unittest {

    import fluid.label;

    auto myLabel = label(.hidden, "The user will never see this label");
    myLabel.draw();  // doesn't draw anything!

}

/// This node property will disable the subject, setting the `isHidden` field to true.
///
/// Params:
///     value = If set to false, the effect is reversed and the node is set to be enabled instead.
/// See_Also: `Node.isDisabled`
auto disabled(bool value = true) {

    static struct Disabled {

        bool value;

        void apply(Node node) {

            node.isDisabled = value;

        }

    }

    return Disabled(value);

}

unittest {

    import fluid.button;

    button(
        .disabled,
        "You cannot press this button!",
        delegate {
            assert(false);
        }
    );


}

/// `HitFilter` is used as a return value of `Node.inBounds`. For most use-cases,
/// `HitFilter.hit` and `HitFilter.miss` are the most appropriate, specifying that the point in
/// question is, or is not, in the node's bounds. This defines the way nodes interact with
/// mouse, touchscreen or other hover events (`fluid.io.hover`).
///
/// The node is not normally responsible for the bounds of its children. Children nodes specify
/// their own bounds separately, so the `HitFilter.hit` and `HitFilter.miss` answers do not
/// affect children.
///
/// Despite the above, it is sometimes desirable to prevent children from taking input, for
/// example to perform transforms. To specify that children nodes *cannot* be in bounds,
/// use `HitFilter.hitBranch` or `HitFilter.missBranch`.
///
/// See_Also:
///     `Node.inBounds`.
enum HitFilter : HitFilterMask {

    /// The point is in bounds of this node.
    hit        = HitFilterMask(0),

    /// The point is *not* in bounds of this node.
    miss       = HitFilterMask(1),

    /// The point is in bounds, but not in the bounds of any of the children nodes.
    hitBranch  = HitFilterMask(2),

    /// Indicates that the point is *not* in bounds of any of the nodes in the branch; neither
    /// of self, nor any of the children nodes.
    missBranch = HitFilterMask(3),

}

/// This bitmask defines whether a node contains a point in its boundaries.
///
/// To allow this to default to `HitFilter.hit` while being
/// [zero-initialized](https://dlang.org/spec/traits.html#isZeroInit), each bit is inverted;
/// i.e. `0` means *yes, in bounds* and `1` means, *no, not in bounds*.
///
/// See_Also:
///     `HitFilter` for all possible values of this bitmask.
///     `Node.inBounds` for a function returning this value.
struct HitFilterMask {
    int bitmask;

    /// Returns:
    ///     True if the queried point can be found in the node itself.
    bool inSelf() const {
        return (bitmask & 1) == 0;
    }

    /// Returns:
    ///     True if the queried point may or may not be found in the children of the node.
    ///     A false value indicates that the point will not be in any of the children nodes,
    ///     and that children nodes should not be tested.
    bool inChildren() const {
        return (bitmask & 2) == 0;
    }

    /// Create a value that combines the restrictions of both masks. It can be said that either
    /// of the masks acts as a "filter", hence the name.
    ///
    /// For example, combining `HitFilter.hit` with `HitFilter.miss` returns `HitFilter.miss`.
    /// Combining `HitFilter.miss` with `HitFilter.hitBranch` returns `HitFilter.missBranch`.
    ///
    /// Params:
    ///     other = Mask to combine with.
    /// Returns:
    ///     A mask with `inSelf == false` if false for either of the masks,
    ///     and similarly `inChildren == false` if false for either of the values.
    HitFilter filter(HitFilterMask other) const {
        return cast(HitFilter) HitFilterMask((bitmask | other.bitmask) & 3);
    }

    /// Set the node's hit filter. This can be used as a node property — a hit filter
    /// can be passed to a node builder.
    /// Params:
    ///     node = Node to change.
    void apply(Node node) {
        node.hitFilter = cast(HitFilter) HitFilterMask(bitmask & 3);
    }
}

static assert(HitFilter.init == HitFilter.hit);
static assert(!HitFilter.miss.inSelf);
static assert( HitFilter.miss.inChildren);
static assert( HitFilter.hit.inSelf);
static assert( HitFilter.hit.inChildren);
static assert(!HitFilter.missBranch.inSelf);
static assert(!HitFilter.missBranch.inChildren);
static assert( HitFilter.hitBranch.inSelf);
static assert(!HitFilter.hitBranch.inChildren);
static assert(HitFilter.hit.filter(HitFilter.miss) == HitFilter.miss);
static assert(HitFilter.miss.filter(HitFilter.hitBranch) == HitFilter.missBranch);
