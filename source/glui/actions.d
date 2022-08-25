/// Definitions for common tree actions; This is the Glui tree equivalent to std.algorithm.
module glui.actions;

import raylib;

import glui.node;
import glui.tree;
import glui.input;


@safe:


/// Set focus on the given node, if focusable, or the first of its focusable children. This will be done lazily during
/// the next draw.
/// Params:
///     parent = Container node to search in.
void focusRecurse(GluiNode parent) {

    // Perform a tree action to find the child
    parent.queueAction(new FocusRecurseAction);

}

class FocusRecurseAction : TreeAction {

    override void beforeDraw(GluiNode node, Rectangle) {

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

}
