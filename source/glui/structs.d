module glui.structs;

/// Represents a node's layout
struct NodeLayout {

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
