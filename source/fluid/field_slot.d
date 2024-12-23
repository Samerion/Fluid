///
module fluid.field_slot;

import fluid.node;
import fluid.utils;
import fluid.input;
import fluid.actions;
import fluid.backend;

import fluid.io.hover;

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
class FieldSlot(T : Node) : T, FluidHoverable, Hoverable {

    mixin makeHoverable;
    mixin FluidHoverable.enableInputActions;
    mixin Hoverable.enableInputActions;

    this(Args...)(Args args) {
        super(args);
    }

    /// Pass focus to the field contained by this slot and press it.
    @(FluidInputAction.press)
    void press() {

        focus()
            .then((Node node) {
                if (auto focusable = cast(FluidFocusable) node) {
                    focusable.runInputAction!(FluidInputAction.press);
                }
            });

    }

    /// Pass focus to the field contained by this slot.
    FocusRecurseAction focus() {

        return this.focusRecurseChildren();

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
    override void mouseImpl() {

    }

    // implements Hoverable
    override bool blocksInput() const {
        return isDisabled || isDisabledInherited;
    }

    // implements Hoverable
    override bool hoverImpl() {
        return false;
    }

}

