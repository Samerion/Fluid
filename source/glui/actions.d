/// Definitions for common tree actions; This is the Glui tree equivalent to std.algorithm.
module glui.actions;

import glui.node;
import glui.tree;
import glui.input;
import glui.backend;
import glui.container;


@safe:


/// Set focus on the given node, if focusable, or the first of its focusable children. This will be done lazily during
/// the next draw. If calling `focusRecurseChildren`, the subject of the call will be excluded from taking focus.
/// Params:
///     parent = Container node to search in.
void focusRecurse(GluiNode parent) {

    // Perform a tree action to find the child
    parent.queueAction(new FocusRecurseAction);

}

/// ditto
void focusRecurseChildren(GluiNode parent) {

    auto action = new FocusRecurseAction;
    action.excludeStartNode = true;

    parent.queueAction(action);

}

class FocusRecurseAction : TreeAction {

    public {

        bool excludeStartNode;

    }

    override void beforeDraw(GluiNode node, Rectangle) {

        // Ignore if the branch is disabled
        if (node.isDisabledInherited) return;

        // Ignore the start node if excluded
        if (excludeStartNode && node is startNode) return;

        // Check if the node is focusable
        if (auto focusable = cast(GluiFocusable) node) {

            // Give it focus
            focusable.focus();

            // We're done here
            stop;

        }

    }

}

/// Scroll so the given node becomes visible.
/// Params:
///     node = Node to scroll to.
void scrollIntoView(GluiNode node) {

    node.queueAction(new ScrollIntoViewAction);

}

class ScrollIntoViewAction : TreeAction {

    private {

        /// The node this action attempts to put into view.
        GluiNode target;

        Vector2 viewport;
        Rectangle childBox;

    }

    override void afterDraw(GluiNode node, Rectangle, Rectangle paddingBox, Rectangle) {

        // Target node was drawn
        if (node is startNode) {

            // Make sure the action reaches the end of the tree
            target = node;
            startNode = null;

            // Get viewport size
            viewport = node.tree.io.windowSize;

            // Get the node's padding box
            childBox = paddingBox;


        }

        // Ignore children of the target node
        // Note: startNode is set until reached
        else if (startNode !is null) return;

        // Reached a container node
        else if (auto container = cast(GluiContainer) node) {

            // Perform the scroll
            childBox = container.shallowScrollTo(node, viewport, paddingBox, childBox);

        }

    }

}
