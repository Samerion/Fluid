/// Base node for node chains. Used for I/O implementations.
module fluid.node_chain;

import fluid.node;
import fluid.types;

@safe:

/// Assemble a node chain out of `NodeChain` nodes.
/// Params:
///     chain = Nodes compromising the chain.
///     node  = Last node in the chain.
/// Returns:
///     The first node in the chain, with all the remaining nodes added as children.
NodeChain chain(Ts...)(Ts chain, Node node) {

    NodeChain tip = chain[0];

    foreach (NodeChain link; chain[1..$]) {
        tip.next = link;
        tip = link;
    }

    tip.next = node;
    return chain[0];

}

/// ditto
Node chain(Node node) {
    return node;
}

/// A node chain makes it possible to create a stack of nodes — one node draws another, which draws another, and so on
/// — in a more efficient manner than nodes usually are drawn.
///
/// The primary usecase of `NodeChain` is I/O stacks, in which each I/O implementation is chained to another.
/// All nodes in the chain but the last must also be subclasses of `NodeChain` for it to work. This means that all
/// components must be designed to support this class. For this reason, most I/O implementations provided by Fluid
/// extend from `NodeChain`.
///
/// `NodeChain` disables some of the basic `Node` functionality. A chain link cannot set margin, border or padding
/// in a way that would make it work, and it also cannot control its own `minSize`. Effectively, a chain will only
/// use the margin/padding of the inner-most node, that is the first non-chain node. Some other functionality like
/// tint, inheriting `isDisabled` etc. may not work too.
abstract class NodeChain : Node {

    private {

        Node _next;
        NodeChain _nextChain;
        NodeChain _previousChain;

        /// If true, `resizeImpl` will quit immediately and reset this value.
        ///
        /// This is used on the assumption that resizing will be performed by NodeChain.
        bool _skipResizeImpl;

    }

    /// Create this node as the last link in chain. No node will be drawn unless changed with `next`.
    this() {

    }

    /// Create this node and set the next node in chain.
    /// Params:
    ///     next = Node to draw inside this node.
    this(Node next) {

        this.next = next;

    }

    /// Set the next node in chain.
    /// Params:
    ///     value = Node to set.
    /// Returns:
    ///     Assigned node.
    Node next(Node value) {

        if (auto chain = cast(NodeChain) value) {
            _nextChain = chain;
        }

        return _next = value;

    }

    /// Returns: The next node in chain, if any.
    inout(Node) next() inout {
        return _next;
    }

    /// Returns: The next node in chain, but only if it's a node chain.
    inout(NodeChain) nextChain() inout {
        return _nextChain;
    }

    protected abstract void beforeResize(Vector2 space);
    protected abstract void afterResize(Vector2 space);

    protected abstract void beforeDraw(Rectangle outer, Rectangle inner);
    protected abstract void afterDraw(Rectangle outer, Rectangle inner);

    alias resizeChild = Node.resizeChild;

    protected Vector2 resizeChild(NodeChain child, Vector2 space) {
        child._skipResizeImpl = true;
        return super.resizeChild(child, space);
    }

    protected override void resizeImpl(Vector2 space) {

        // Called from another `nodeChain`, skip this call
        if (_skipResizeImpl) {
            _skipResizeImpl = false;
            return;
        }

        // Call beforeResize on each part
        NodeChain chain = this;
        while (true) {

            // Perform traditional resize and follow up with beforeResize
            resizeChild(chain, space);
            chain.beforeResize(space);

            // Update the chain
            if (chain.nextChain) {
                chain.nextChain._previousChain = chain;
                chain = chain.nextChain;
            }
            else break;

        }

        // Resize the innermost child
        if (chain.next) {
            resizeChild(chain.next, space);
            minSize = chain.next.minSize;
        }

        // Call afterResize on each part
        while (chain) {
            chain.afterResize(space);
            chain = chain._previousChain;
        }

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        // Call beforeDraw on each part
        NodeChain chain = this;
        while (true) {

            // Run tree actions
            foreach (action; tree.filterActions) {
                action.beforeDrawImpl(chain, outer, outer, inner);
            }

            // Call beforeResize
            chain.beforeDraw(outer, inner);

            // Update the chain
            if (chain.nextChain) {
                chain.nextChain._previousChain = chain;
                chain = chain.nextChain;
            }
            else break;

        }

        // Draw the innermost child
        if (chain.next) {
            drawChild(chain.next, inner);
        }

        // Call afterDraw on each part
        while (chain) {
            chain.afterDraw(outer, inner);
            foreach (action; tree.filterActions) {
                action.beforeDrawImpl(chain, outer, outer, inner);
            }
            chain = chain._previousChain;
        }

    }

}
