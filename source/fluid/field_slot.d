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

    /// Create the field slot
    ///
    /// Params:
    ///     args = Same arguments as required by the base node; `new FieldSlot!T`
    ///         accepts the same arguments as `new T`. For example, `FieldSlot!Frame` will take
    ///         a list of children nodes just like `Frame` would.
    this(Args...)(Args args) {
        super(args);
    }

    /// Pass focus to the field contained by this slot and then press it. This action will take
    /// a frame to perform.
    ///
    /// This function is the event handler for [FluidInputAction.press].
    @(FluidInputAction.press)
    void press() {
        focusAnd.then((Node node) {
            if (auto focusable = cast(FluidFocusable) node) {
                focusable.runInputAction!(FluidInputAction.press);
            }
        });
    }

    /// Pass focus to the field contained by this slot and then press it. This action will take
    /// a frame to perform.
    void focus() {
        cast(void) focusAnd();
    }

    /// Pass focus to the field contained by this slot. Unlike [focus], this method can be chained
    /// to perform action once the focus is set.
    ///
    /// Returns:
    ///     The [FocusRecurseAction] tree action used to search the tree.
    FocusRecurseAction focusAnd() {
        auto action = this.focusRecurseChildren();
        action.then(&setFocusableChild);
        return action;
    }

    /// `focusAnd` will asynchronously focus an input node inside. `then` can be
    /// used to perform an action once it the node is found.
    ///
    /// Note that the parameter given by `then` can be null.
    @("Chaining FieldSlot")
    unittest {
        import fluid;

        TextInput nameInput;

        auto slot = fieldSlot!hframe(
            label("Name"),
            nameInput = textInput(),
        );
        auto action = slot
            .focusAnd()
            .then((Node target) {
                assert(target is nameInput);
            });

        // Run the test
        auto root = testSpace(slot);
        action.runWhileDrawing(root);
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

