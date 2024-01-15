///
module fluid.structs;

import std.conv;


@safe:


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

/// Represents a node's layout
struct Layout {

    /// Fraction of available space this node should occupy in the node direction.
    ///
    /// If set to `0`, the node doesn't have a strict size limit and has size based on content.
    uint expand;

    /// Align the content box to a side of the occupied space.
    NodeAlign[2] nodeAlign;

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

/// FluidNode core constructor parameters, to be passed from node to node.
struct NodeParams {

    import fluid.style;

    Layout layout;
    Theme theme;

    this(Layout layout, Theme theme = null) {

        this.layout = layout;
        this.theme  = theme;

    }

    /// Ditto
    this(Theme theme, Layout layout = Layout.init) {

        this(layout, theme);

    }

}
