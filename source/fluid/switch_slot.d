/// [SwitchSlot] is an **experimental** node that tries nodes from a list, and uses the first that
/// can fit in available space.
///
/// [switchSlot] is available to use as a node builder.
module fluid.switch_slot;

@safe:

import fluid.node;
import fluid.utils;
import fluid.style;

/// [nodeBuilder] for [SwitchSlot]. Takes a list of nodes, in order from largest to smallest,
/// optionally terminated with a `null` to indicate nothing should be displayed if no node fits.
alias switchSlot = nodeBuilder!SwitchSlot;

/// A switch slot will try each of its children and pick the first one that fits the available
/// space. If the a node is too large to fit, it will try the next one in the list until it finds
/// one that matches, or the last node in the list.
///
/// `null` is an acceptable child for `SwitchSlot`, indicating that no node should be drawn.
class SwitchSlot : Node {

    public {

        /// Array of nodes to test, tested in order. The first node that fits inside space
        /// available to `SwitchSlot` will be chosen.
        ///
        /// If no node can fit, the last node on the list will be picked, which may be `null`.
        /// In case `null` is picked, no node will be displayed.
        Node[] availableNodes;

        /// Node to chosen by the slot to display.
        Node node;

        /// If present, this node will only be drawn in case its principal node is hidden.
        ///
        /// `SwitchSlot` will be hidden if it picks `null` for a child node. This can be used
        /// to set another slot as a fallback, given it appears in a later spot in the tree.
        Node principalNode;

    }

    protected {

        /// Last available space assigned to this node.
        Vector2 _availableSpace;

    }

    alias isHidden = typeof(super).isHidden;

    /// Returns:
    ///     True if the slot is marked as [hidden][Node.isHidden], or if it chose
    ///     `null` as a child among available candidates.
    override bool isHidden() const return {

        // Tree is available and resized
        if (!isResizePending) {

            // Principal node is visible, hide self
            if (principalNode && !principalNode.isHidden)
                return true;

            // Hide if no node was chosen
            return super.isHidden || node is null;

        }

        return super.isHidden;

    }

    /// Params:
    ///     nodes = Array of candidates to use in the slot.
    ///         The nodes will be tested in order as given, and the first one that matches
    ///         will be used.
    /// See_Also:
    ///     [availableNodes] for more details on how nodes are picked.
    this(Node[] nodes...) {
        this.availableNodes ~= nodes;
    }

    /// Create a new slot that will only draw if this slot is hidden or ends up with a `null`
    /// node. For this to work, the "retry" slot must appear later in the tree.
    ///
    /// Params:
    ///     args = Arguments to pass to the slot's constructor; candidate nodes.
    ///         See [constructor](#.SwitchSlot.this).
    /// Returns:
    ///     Created slot.
    SwitchSlot retry(Args...)(Args args) {
        auto slot = switchSlot(args);
        slot.principalNode = this;
        return slot;
    }

    override void resizeImpl(Vector2 availableSpace) {
        minSize = Vector2();
        this.node = null;
        _availableSpace = availableSpace;

        // Try each option
        foreach (i, node; availableNodes) {
            this.node = node;

            // Null node reached, stop with no minSize
            if (node is null) return;

            auto previousTree = node.tree;
            auto previousTheme = node.theme;
            auto previousSize = node.minSize;

            resizeChild(node, availableSpace);

            // Stop if it fits within available space
            if (node.minSize.x <= availableSpace.x && node.minSize.y <= availableSpace.y) break;

            // Restore previous info, unless this is the last node
            if (i+1 != availableNodes.length && previousTree) {

                // Resize the node again to recursively restore old parameters
                node.tree = null;
                node.inheritTheme(Theme.init);
                resizeChild(node, previousSize);

            }
        }

        // Copy minSize
        minSize = node.minSize;
    }

    override void drawImpl(Rectangle outer, Rectangle inner) {
        if (node is null) return;
        drawChild(node, inner);
    }

    override bool hoveredImpl(Rectangle, Vector2) const {
        return false;
    }

}
