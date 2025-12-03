/// [FieldSlot] wraps an input node, expanding its hitbox to cover other surrounding nodes.
///
/// It can be constructed with the [fieldSlot] node builder.
module fluid.field_slot;

@safe:

///
@("fieldSlot example")
unittest {
    import fluid;

    fieldSlot!vframe(
        label("Username"),
        textInput(),
    );
}

import fluid.node;
import fluid.utils;
import fluid.input;
import fluid.actions;
import fluid.backend;

import fluid.io.hover;
import fluid.io.focus;

/// Node builder for [FieldSlot].
///
/// It accepts a single template parameter to define container type the slot should use:
/// for example `fieldSlot!vframe` will act like a vertical [Frame][fluid.frame], and a
/// `fieldSlot!onionFrame` will act like an [OnionFrame][fluid.onion_frame].
///
/// Other than that, the constructor accepts the same arguments as the node picked;
/// `fieldSlot!vframe` will take a list of children, just like `vframe` would.
alias fieldSlot(alias node) = nodeBuilder!(FieldSlot, node);

/// A field slot is a node meant to hold an input node along with associated
/// nodes, like labels. It's functionally equivalent to the [`<label>` element in
/// HTML](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/label).
///
/// Fields expand the interactable (clickable) area of input nodes by other nodes that are placed
/// inside the slot. For example, in the code snippet below, if the user clicks on the "username"
/// label, the text input underneath will gain focus.
class FieldSlot(T : Node) : T, FluidHoverable, Hoverable, Focusable {

    mixin makeHoverable;
    mixin FluidHoverable.enableInputActions;
    mixin Hoverable.enableInputActions;

    private {
        Focusable _focusableChild;
    }

    this(Args...)(Args args) {
        super(args);
    }

    /// Pass focus to the field contained by this slot and press it.
    @(FluidInputAction.press)
    void press() {

        focusAnd.then((Node node) {
            if (auto focusable = cast(FluidFocusable) node) {
                focusable.runInputAction!(FluidInputAction.press);
            }
        });

    }

    /// Pass focus to the field contained by this slot.
    void focus() {
        cast(void) focusAnd();
    }

    /// ditto
    FocusRecurseAction focusAnd() {

        auto action = this.focusRecurseChildren();
        action.then(&setFocusableChild);
        return action;

    }

    private void setFocusableChild(Focusable focus) {
        _focusableChild = focus;
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

    override bool blocksInput() const {
        return isDisabled || isDisabledInherited;
    }

    override bool hoverImpl(HoverPointer) {
        return false;
    }

    override bool focusImpl() {
        return false;
    }

    override bool isFocused() const {
        return _focusableChild && _focusableChild.isFocused();
    }

}

