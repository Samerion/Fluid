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

unittest {

    import fluid.frame;
    import fluid.label;
    import fluid.structs;
    import fluid.text_input;

    TextInput input;

    auto io = new HeadlessBackend;
    auto root = fieldSlot!vframe(
        layout!"fill",
        label("Hello, World!"),
        input = textInput(),
    );

    root.io = io;
    root.draw();

    assert(!input.isFocused);

    // In this case, clicking anywhere should give the textInput focus
    io.nextFrame;
    io.mousePosition = Vector2(200, 200);
    io.press;
    root.draw();

    assert(root.tree.hover is root);

    // Trigger the event
    io.nextFrame;
    io.release;
    root.draw();

    // Focus should be transferred once actions have been processed
    io.nextFrame;
    root.draw();

    assert(input.isFocused);

}

unittest {

    import fluid.space;
    import fluid.label;
    import fluid.structs;
    import fluid.text_input;
    import fluid.default_theme;

    Label theLabel;
    TextInput input;

    // This time around use a vspace, so it won't trigger hover events when pressed outside
    auto io = new HeadlessBackend;
    auto root = fieldSlot!vspace(
        layout!"fill",
        nullTheme,
        theLabel = label("Hello, World!"),
        input = textInput(),
    );

    root.io = io;
    root.draw();

    assert(!input.isFocused);

    // Hover outside
    io.nextFrame;
    io.mousePosition = Vector2(500, 500);
    root.draw();

    assert(root.tree.hover is null);

    // Hover the label
    io.nextFrame;
    io.mousePosition = Vector2(5, 5);
    io.press;
    root.draw();

    // The root should take the hover
    assert(theLabel.isHovered);
    assert(root.tree.hover is root);

    // Trigger the event
    io.nextFrame;
    io.release;
    root.draw();

    // Focus should be transferred once actions have been processed
    io.nextFrame;
    root.draw();

    assert(input.isFocused);

}
