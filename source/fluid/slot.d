/// A [NodeSlot] acts as a wrapper, it holds and displays a single other node.
module fluid.slot;

@safe:

/// The main use of slots is to replace nodes inside the tree.
@("NodeSlot example")
unittest {
    import fluid.label;
    import fluid.frame;
    import fluid.button;

    NodeSlot!Label currentLabel;

    run(
        vframe(
            currentLabel = nodeSlot!Label(
                label("Hello, World!"),
            ),

            // Click the button to replace the label with another
            button(
                "Replace text",
                delegate {
                    currentLabel.value = label("Goodbye, World!");
                }
            ),
        ),
    );
}

/// For example, [NodeSlot] can be used to implement tabs
@("NodeSlot tab")
unittest {
    import std.range;
    import fluid.label;
    import fluid.button;
    import fluid.frame;
    import fluid.slider;
    import fluid.number_input;

    auto audio = vframe(
        hframe(
            label(     .layout!1, "Music volume"),
            slider!int(.layout!1, iota(0, 101)),
        ),
        hframe(
            label(     .layout!1, "Sound effects volume"),
            slider!int(.layout!1, iota(0, 101)),
        ),
    );
    auto video = vframe(
        hframe(
            label(.layout!2, "Resolution"),
            intInput(.layout!(1, "fill"), 800),
            intInput(.layout!(1, "fill"), 600),
        ),
    );

    NodeSlot!Frame currentTab;
    run(
        vframe(
            // Tab bar
            hframe(
                button("Audio", delegate {
                    currentTab.value = audio;
                }),
                button("Video", delegate {
                    currentTab.value = video;
                }),
            ),
            // Tab contents
            currentTab = nodeSlot!Frame(audio),
        ),
    );
}

import std.traits;

import fluid.node;
import fluid.utils;
import fluid.style;
import fluid.structs;

import fluid.io.canvas;


/// Creates a [NodeSlot] which accepts a single node of type `T` as a child.
alias nodeSlot(alias T) = simpleConstructor!(NodeSlot!T);

///
@("nodeSlot builder example")
unittest {
    import fluid.button;
    import fluid.frame;
    import fluid.label;

    // The template parameter restricts which nodes can be placed in the slot
    nodeSlot!Button();  // This node slot accepts buttons
    nodeSlot!Frame();   // This slot accepts frames
    nodeSlot!Node();    // Any node can fit

    // You can place a node in the slot immediately.
    nodeSlot!Label(
        label("Hello, World!"),
    );
}

/// Layout has to be set on `NodeSlot` to be functional.
@("nodeSlot builder layout example")
unittest {
    import fluid.label;

    // This label will be centered:
    nodeSlot!Label(
        .layout!"center",
        label("Hello, World!"),
    );
}

/// To use `layout!"fill"`, set it on both the slot, and the child node
unittest {
    import fluid.button;

    nodeSlot!Button(
        .layout!(1, "fill"),
        button(
            .layout!"fill",
            "This button fills the slot, and the slot fills available space",
            delegate { }
        ),
    );
}

/// `NodeSlot` is a container node that holds and displays up to one other node.
///
/// The child node can be optionally passed into the constructor, or assigned via the
/// [`value`](#.NodeSlot.value) field.
///
/// The child node is always given all of the available space (the child's `expand` field has
/// no effect).
class NodeSlot(T : Node) : Node {

    CanvasIO canvasIO;

    public {

        /// Node placed in the slot; child node.
        T value;

    }

    /// Create a new node slot and optionally place a node within.
    /// Params:
    ///     node = Child node to place inside the slot.
    this(T node = null) {
        this.value = node;
    }

    /// Change the node in the slot. The new node will replace whatever node that was placed
    /// previously.
    ///
    /// The slot will be [marked for resize][Node.updateSize].
    ///
    /// Note:
    ///     It might be generally preferable to use [`value`](#.NodeSlot.value) directly, as it
    ///     makes the intent more clear.
    /// Params:
    ///     value = Node to place in the slot.
    ///         If null, child node will be removed.
    /// Returns:
    ///     The node slot.
    typeof(this) opAssign(T value) {
        updateSize();
        this.value = value;
        return this;
    }

    /// Remove the child node from the slot, if any.
    ///
    /// Marks the node [for resize][Node.updateSize].
    void clear() {
        value = null;
        updateSize();
    }

    ///
    @("NodeSlot.clear example")
    unittest {
        import fluid.label;

        Label child;
        auto slot = nodeSlot!Label(
            child = label("The node slot contains a label"),
        );
        assert(slot.value is child);
        slot.clear();
        assert(slot.value is null);
    }

    /// Swap contents of two node slots.
    ///
    /// Node slots can restrict their contents to specific node types. Since a `NodeSlot!Label`
    /// can only accept labels, it could not be swapped with `NodeSlot!Frame`, as the labels and
    /// frames are not compatible.
    ///
    /// Node slots of the same type can always swap contents, so a pair such as `NodeSlot!Node`
    /// and `NodeSlot!Node` will swap without fail. Otherwise, nodes held in both must be
    /// cross-compatible: If node slot `a` and node slot `b` are swapped, then `b`'s child must be
    /// accepted by `a` and `a`'s child must be accepted by `b`. This will condition be enforced
    /// at runtime and cannot be caught.
    ///
    /// The best way to avoid runtime errors is to only swap between slots of the same type.
    ///
    /// Child nodes of either slot can be null.
    ///
    /// Params:
    ///     other = The other slot to swap child nodes with.
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

                assert(canAcceptTheirs,
                    format!"Can't swap: This slot doesn't accept %s"(typeid(theirs)));
                assert(canAcceptOurs,
                    format!"Can't swap: Other slot doesn't accept %s"(typeid(ours)));

                // Perform the swap
                value = theirs;
                other.value = ours;

            }
            else static assert(false, "Slots given to swapSlots are not compatible");

        }
        else static assert(false, "The other item is not a NodeSlot");
    }

    ///
    @("NodeSlot.swapSlots usage example")
    unittest {
        import fluid.label;

        // Box of apples, bucket of oranges
        auto box = nodeSlot!Label(
            label("Apples"),
        );
        auto bucket = nodeSlot!Label(
            label("Oranges"),
        );

        // Swap them: put apples in the bucket, oranges in the box
        box.swapSlots(bucket);
        assert(box.value.text == "Oranges");
        assert(bucket.value.text == "Apples");
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
        pickStyle().drawBackground(canvasIO, outer);

        if (!value) return;

        drawChild(value, inner);
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
