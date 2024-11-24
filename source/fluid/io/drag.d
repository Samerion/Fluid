/// This module provides core infrastructure for drag & drop functionality.
module fluid.io.drag;

import fluid.node;
import fluid.tree.types;

@safe:

/// Interface for container nodes that support dropping other nodes inside.
interface FluidDroppable {

    /// Returns true if the given node can be dropped into this node.
    bool canDrop(Node node);

    /// Called every frame an eligible node is hovering the rectangle. Used to provide feedback while drawing the
    /// container node.
    /// Params:
    ///     position  = Screen cursor position.
    ///     rectangle = Rectangle used by the node, relative to the droppable.
    void dropHover(Vector2 position, Rectangle rectangle);

    /// Specifies the given node has been dropped inside the container.
    /// Params:
    ///     position  = Screen cursor position.
    ///     rectangle = Rectangle used by the node, relative to the droppable.
    ///     node      = Node that has been dropped.
    void drop(Vector2 position, Rectangle rectangle, Node node);

}
