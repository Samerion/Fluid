module glui.container;

import raylib;

import glui.node;
import glui.tree;
import glui.input;


@safe:


/// A interface for nodes that contain and control other nodes.
///
/// See_Also: https://git.samerion.com/Samerion/Glui/issues/14
interface GluiContainer {

    /// Set focus on the first available focusable node.
    final void focusChild() {

        focusChild(getTree);

    }

    /// ditto
    final void focusChild(LayoutTree* tree) {

        auto parent = this.asNode;

        // Perform a tree action to find the child
        tree.queueAction(new class TreeAction {

            bool parentFound;

            override void beforeDraw(GluiNode node, Rectangle) {

                // Find the parent
                if (node is parent) {
                    parentFound = true;
                    return;
                }

                // Only run once found
                if (!parentFound) return;

                // Ignore if the branch is disabled
                if (node.isDisabledInherited) return;

                // Check if the node is focusable
                if (auto focusable = cast(GluiFocusable) node) {

                    // Give it focus
                    focusable.focus();

                    // We're done here
                    stop;

                }

            }

        });

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
