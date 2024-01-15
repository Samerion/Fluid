module fluid.container;

import fluid.node;
import fluid.tree;
import fluid.input;
import fluid.actions;
import fluid.backend;


@safe:


/// A interface for nodes that contain and control other nodes.
///
/// See_Also: https://git.samerion.com/Samerion/Glui/issues/14
interface GluiContainer {

    /// Scroll towards the given children node. This should change the parent's properties (without affecting the child)
    /// so that the child enters the viewport, or becomes as close to it as possible.
    /// Params:
    ///     child     = Node to scroll towards. Must be a direct child of this node.
    ///     viewport  = Size of the current viewport. The parent should
    ///     parentBox = This node's current padding box.
    ///     childBox  = The child's current padding box.
    /// Returns:
    ///     Estimated new padding box for the child.
    /// See_Also:
    ///     `glui.actions.scrollIntoView` for recursive scrolling via `TreeAction`.
    Rectangle shallowScrollTo(GluiNode child, Vector2 viewport, Rectangle parentBox, Rectangle childBox);

    /// Set focus on the first available focusable node in this tree.
    final void focusChild() {

        asNode.focusRecurseChildren();

    }

    final inout(GluiNode) asNode() inout {

        import std.format;

        auto node = cast(inout GluiNode) this;

        assert(node, format!"%s : GluiContainer must inherit from a Node"(typeid(this)));

        return node;

    }

    private final LayoutTree* getTree()
    out (r; r !is null, "Container needs a resize to associate with a tree")
    do {

        return asNode.tree;

    }

}
