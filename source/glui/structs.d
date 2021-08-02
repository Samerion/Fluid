///
module glui.structs;

import std.conv;
import glui.node;

/// Create a new layout
/// Params:
///     expand = Numerator of the fraction of space this node should occupy in the parent.
///     align_ = Align of the node (horizontal and vertical).
///     alignX = Horizontal align of the node.
///     alignY = Vertical align of the node.
Layout layout(uint expand, NodeAlign alignX, NodeAlign alignY) {

    return Layout(expand, [alignX, alignY]);

}

/// Ditto
Layout layout(uint expand, NodeAlign align_) {

    return Layout(expand, align_);

}

/// Ditto
Layout layout(NodeAlign alignX, NodeAlign alignY) {

    return Layout(0, [alignX, alignY]);

}

/// Ditto
Layout layout(NodeAlign align_) {

    return Layout(0, align_);

}

/// Ditto
Layout layout(uint expand) {

    return Layout(expand);

}

/// CTFE version of the layout constructor, allows using strings instead of enum members, to avoid boilerplate.
Layout layout(uint expand, string alignX, string alignY)() {

    return Layout(expand, [alignX.to!NodeAlign, alignY.to!NodeAlign]);

}

/// Ditto
Layout layout(uint expand, string align_)() {

    return Layout(expand, align_.to!NodeAlign);

}

/// Ditto
Layout layout(string alignX, string alignY)() {

    return Layout(0, [alignX.to!NodeAlign, alignY.to!NodeAlign]);

}

/// Ditto
Layout layout(string align_)() {

    return Layout(0, align_.to!NodeAlign);

}

/// Ditto
Layout layout(uint expand)() {

    return Layout(expand);

}

/// Represents a node's layout
struct Layout {

    /// Fraction of available space this node should occupy in the node direction.
    ///
    /// If set to `0`, the node doesn't have a strict size limit and has size based on children.
    uint expand;

    /// Align the content box to a side of the occupied space.
    NodeAlign[2] nodeAlign;

}

enum NodeAlign {

    start, center, end, fill

}

interface GluiFocusable {

    void focus();

}

/// Global data for the layout tree.
struct LayoutTree {

    /// Root node of the tree.
    GluiNode root;

    /// Currently focused node.
    GluiFocusable focus;

    /// Registered mouse callback.
    void delegate() mouseInput;

    /// Registered misc. callbacks.
    void delegate() keyboardInput;

}
