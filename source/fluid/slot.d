module fluid.slot;

import std.traits;

import fluid.node;
import fluid.utils;
import fluid.style;
import fluid.backend;
import fluid.structs;

import fluid.io.canvas;

@safe:


/// A "node slot" node, which displays the node given to it. Allows safely swapping nodes in the layout by reference,
/// even during drawing. Useful for creating tabs and menus.
///
/// Because NodeSlot does not inherit from T, it uses the single-parameter overload of simpleConstructor.
alias nodeSlot(alias T) = simpleConstructor!(NodeSlot!T);

/// ditto
class NodeSlot(T : Node) : Node {

    CanvasIO canvasIO;

    public {

        /// Node placed in the slot.
        T value;

    }

    /// Create a new node slot and optionally place a node within.
    this(T node = null) {

        this.value = node;

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

    /// Remove the assigned node from the slot.
    void clear() {

        value = null;
        updateSize();

    }

    protected override void resizeImpl(Vector2 space) {

        use(canvasIO);

        minSize = Vector2();

        // Don't resize if there's no child node
        if (!value) return;

        // Remove the value if requested
        if (value.toRemove) {
            value = null;
            return;
        }

        resizeChild(value, space);
        minSize = value.minSize;

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        pickStyle().drawBackground(io, canvasIO, outer);

        if (!value) return;

        drawChild(value, inner);

    }

    protected override bool hoveredImpl(Rectangle rect, Vector2 position) {

        if (!value) return false;

        // If the child has ignoreMouse set, we should ignore it as well
        if (value.ignoreMouse) return false;

        // hoveredImpl may be private... uhhh
        return (cast(Node) value).hoveredImpl(rect, position);

    }

    /// Swap contents of the two slots.
    void swapSlots(Slot : Node)(Slot other) {

        static if (is(Slot : NodeSlot!U, U)) {

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

}

///
unittest {

    import fluid;

    NodeSlot!Label slot1, slot2;

    // Slots can be empty, with no node inside
    auto root = vspace(
        label("Hello, "),
        slot1 = nodeSlot!Label(.layout!"fill"),
        label(" and "),
        slot2 = nodeSlot!Label(.layout!"fill"),
    );

    // Slots can be assigned other nodes
    slot1 = label("John");

    slot2 = button("Jane", delegate {

        // Slot contents can be swapped with a single call
        slot1.swapSlots(slot2);

    });

    // Slots can be reassigned at any time
    slot1 = label("Joe");

    // Their values can also be removed
    slot1.clear();

}
