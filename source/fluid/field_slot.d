///
module fluid.field_slot;

import fluid.node;
import fluid.utils;
import fluid.input;
import fluid.actions;
import fluid.backend;


@safe:


/// A field slot is a node meant to hold an input node along with associated nodes, like labels. It's functionally
/// equivalent to the [`<label>` element in HTML](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/label).
///
/// Fields expand the interactable (clickable) area of input nodes by other nodes that are placed inside the slot. For
/// example, in the code snippet below, if the user clicks on the "username" label, the text input underneath will gain
/// focus.
///
/// ---
/// fieldSlot!vframe(
///     label("Username"),
///     textInput(),
/// )
/// ---
alias fieldSlot(alias node) = simpleConstructor!(FieldSlot, node);

/// ditto
class FieldSlot(T : Node) : T, FluidHoverable {

    mixin makeHoverable;
    mixin enableInputActions;

    this(Args...)(Args args) {
        super(args);
    }

    /// Pass focus to the field contained by this slot.
    @(FluidInputAction.press)
    void focus() {

        auto action = this.focusRecurseChildren();

        // Press the target when found
        action.finished = (node) {
            if (node) {
                node.runInputAction!(FluidInputAction.press);
            }
        };

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        const previousHover = tree.hover;

        // Draw children
        super.drawImpl(outer, inner);

        // Test if hover has switched to any of them
        const isChildHovered = tree.hover !is previousHover;

        // If the node doesn't handle hover itself, take over
        // (pun not intended)
        if (isChildHovered && !cast(FluidHoverable) tree.hover) {

            tree.hover = this;

        }

    }

    // implements FluidHoverable
    override bool isHovered() const {
        return tree.hover is this
            || super.isHovered();
    }

    // implements FluidHoverable
    void mouseImpl() {

    }

}

