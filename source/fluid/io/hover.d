/// This module implements interfaces for handling hover and connecting hoverable nodes with input devices.
module fluid.io.hover;

import fluid.future.context;

import fluid.io.action;

public import fluid.io.action : InputEvent, InputEventCode;

@safe:

/// `HoverIO` is an input handler system that reads events off devices with the ability to point at the screen,
/// like mouses, touchpads or pens.
///
/// Most of the time, `HoverIO` systems will pass the events they receive to an `ActionIO` system, and then send
/// these actions to a hovered node.
///
/// Multiple different `HoverIO` instances can coexist in the same tree, allowing for multiple different nodes
/// to be hovered at the same time, as long as they belong in different branches of the node tree. That means
/// two different nodes can be hovered by two different `HoverIO` systems, but a single `HoverIO` system can only
/// hover a single node.
interface HoverIO : IO {

    /// Read an input event from an input device. Input devices will call this function every frame 
    /// if an input event occurs.
    ///
    /// `HoverIO` will usually pass these down to an `ActionIO` system. It is up to `HoverIO` to decide how 
    /// the input and the resulting input actions is handled, though the hovered node will most often receive
    /// them.
    ///
    /// Params:
    ///     event = Input event the system should save.
    void emitEvent(InputEvent event);

    /// Returns:
    ///     The currently hovered node, or `null` if no hoverable node is at the moment.
    inout(Hoverable) currentHover() inout;

    /// Change the currently hovered node to another.
    ///
    /// This function may frequently be passed `null` with the intent of clearing the hovered node.
    ///
    /// Params:
    ///     newValue = Node to assign hover to.
    /// Returns:
    ///     Node that was focused, to allow chaining assignments.
    Hoverable currentHover(Hoverable newValue);

}

/// Nodes implementing this interface can be selected by a `HoverIO` system.
interface Hoverable : Actionable {

    /// Handle input. Called each frame when focused.
    /// Returns:
    ///     True if hover was handled, false if it was ignored.
    bool hoverImpl();

    /// Mark this node as hovered.
    ///
    /// A node will usually redirect this call to `hoverIO.hover()`, but it might instead pass the status to another
    /// hoverable node.
    void hover();

    /// Returns: 
    ///     True if this node is hovered.
    ///     This will most of the time be equivalent to `this == hoverIO.hover`, 
    ///     but a node wrapping another hoverable may choose to instead redirect this to the other node.
    bool isHovered() const;

}
