module glui.slot;

import raylib;

import std.traits;

import glui.node;
import glui.utils;
import glui.style;
import glui.structs;


@safe:


/// Quickly create a node slot.
alias nodeSlot(T) = simpleConstructor!(GluiNodeSlot!T);

/// A "node slot" node, which displays the node given to it. Allows safely swapping nodes in the layout by reference,
/// even during drawing.
class GluiNodeSlot(T : GluiNode) : GluiNode {

    /// GluiNodeSlot defines its own styles, which will only apply to the slot itself, not the contents. Most of the
    /// styling options will have no effect, but padding and margin will.
    mixin DefineStyles;

    public {

        /// Node placed in the slot.
        T value;

        /// If true, the slot will inherit its layout from the node it holds. If there's no node, it'll be reset to
        /// shrink.
        bool inheritLayout;

    }

    /// Create a new slot and place a node in it.
    this(Layout layout, T node) {

        this.value = node;
        this.layout = layout;

    }

    this(T node) {

        this.value = node;
        updateLayout();

    }

    /// Create a new empty slot.
    this(Layout layout = Layout.init) {

        this.layout = layout;

    }

    /// Change the node in the slot.
    ///
    /// This function is a little bit more convenient than setting the value directly, as it'll mark itself as
    /// needing an update. Additionally, it returns the slot, not the given node, so you can assign a value to a
    /// constructed slot while adding it to the scene tree.
    typeof(this) opAssign(T value) {

        updateSize();

        this.value = value;

        return this;

    }

    protected override void resizeImpl(Vector2 space) {

        if (!value) return;

        updateLayout();

        value.resize(tree, theme, space);
        minSize = value.minSize;

    }

    protected override void drawImpl(Rectangle paddingBox, Rectangle contentBox) {

        if (!value) return;

        updateLayout();

        value.draw(contentBox);

    }

    protected override bool hoveredImpl(Rectangle rect, Vector2 position) const {

        if (!value) return false;

        // hoveredImpl may be private... uhhh
        return (cast(const GluiNode) value).hoveredImpl(rect, position);

    }

    override const(Style) pickStyle() const {

        return style;

    }

    /// Swap contents of the two slots.
    void swapSlots(Slot : GluiNode)(Slot other) {

        static if (is(Slot : GluiNodeSlot!U, U)) {

            import std.format;
            import std.algorithm;

            updateSize();

            static if (is(T == U)) {

                swap(value, other.value);

            }

            else static if (is(T : U) || is(U : T)) {

                auto theirs = cast(T) other.value;
                auto ours   = cast(U) value;

                const canAcceptTheirs = theirs || other.value is null;
                const canAcceptOurs   = ours   || value is null;

                assert(canAcceptTheirs, format!"Can't swap: This slot doesn't accept %s"(typeid(theirs)));
                assert(canAcceptOurs,   format!"Can't swap: Other slot doesn't accept %s"(typeid(ours)));

                // Perform the swap
                value = theirs;
                other.value = ours;

            }

            else static assert(false, "Slots given to swapSlots are not compatible");

        }

        else static assert(false, "The other item is not a node");

    }

    private void updateLayout() {

        assert(value);

        if (inheritLayout) {

            layout = value.layout;

        }

    }

}
