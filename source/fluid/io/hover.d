/// This module implements interfaces for handling hover and connecting hoverable nodes with input devices.
module fluid.io.hover;

import std.range;

import fluid.tree;
import fluid.types;

import fluid.future.pipe;
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

    /// Load a pointer (mouse cursor, finger) and place it at the position currently indicated in the struct.
    /// Update the pointer's position if already loaded.
    ///
    /// It is expected `load` will be called after every pointer motion in order to keep its position up to date.
    ///
    /// A pointer is considered loaded until the next resize. If the `load` call for a pointer isn't repeated
    /// during a resize, the pointer is invalidated. Pointers do not have to be loaded while resizing; they can 
    /// also be loaded while drawing.
    ///
    /// An example implementation of a pointer device, from inside of a node, could look like:
    ///
    /// ---
    /// HoverIO hoverIO;
    /// Pointer pointer;
    ///
    /// override void resizeImpl(Vector2) {
    ///     require(hoverIO);
    ///     minSize = Vector2();
    /// }
    /// 
    /// override void drawImpl(Rectangle, Rectangle) {
    /// 
    ///     pointer.device = this;
    ///     pointer.number = 0;
    ///     pointer.position = mousePosition();
    ///     load(mouseIO, pointer);
    ///     if (clicked) {
    ///         mouseIO.emitEvent(pointer, MouseIO.createEvent(MouseIO.Button.left, true));
    ///     }
    ///
    /// }
    /// ---
    /// 
    /// Params:
    ///     pointer = Pointer to prepare.
    ///         The pointer's `device` field should be set to whatever node represents this device,
    ///         and the `number` field should be set to whatever number the device can associate with the pointer,
    ///         if multiple pointers are to be used.
    /// Returns:
    ///     An ID the `HoverIO` system will use to recognize the pointer.
    int load(Pointer pointer);

    /// Read an input event from an input device. Input devices will call this function every frame 
    /// if an input event (such as a button press) occurs. Moving a mouse does not qualify as an input event.
    ///
    /// The pointer emitting the event must have been loaded earlier (using `load`) during the same frame 
    /// for the action to work.
    ///
    /// `HoverIO` will usually pass these down to an `ActionIO` system. It is up to `HoverIO` to decide how
    /// the input and the resulting input actions is handled, though the node hovered by the pointer will most 
    /// often receive them.
    ///
    /// Params:
    ///     pointer = Pointer that emitted the event.
    ///     event   = Input event the system should emit.
    ///         The event is usually considered "active" during the frame the action is "released". For example,
    ///         user stops holding a mouse button, or a finger stops touching the screen.
    void emitEvent(Pointer pointer, InputEvent event);

    /// Params:
    ///     pointer = Pointer to query. The pointer must be loaded.
    /// Returns:
    ///     Node hovered by the pointer.
    inout(Hoverable) hoverOf(Pointer pointer) inout;

    /// Returns: 
    ///     True if the node is hovered.
    /// Params:
    ///     hoverable = True if this node is hovered.
    bool isHovered(const Hoverable hoverable) const;

    /// List all currently hovered nodes.
    /// Params:
    ///     yield = A delegate to be called for every hovered node.
    ///         This should include nodes that block input, but are hovered. 
    ///         If the delegate returns a non-zero value, the value should be returned.
    /// Returns:
    ///     If `yield` returned a non-zero value, this is the value it returned;
    ///     if `yield` wasn't called, or has only returned zeroes, a zero is returned.
    int opApply(int delegate(Hoverable) @safe yield);

}

/// Returns:
///     True if the `hoverIO` is hovering some node.
/// Params:
///     hoverIO   = HoverIO to test.
///     hoverable = Node that HoverIO is expected to hover.
bool hovers(HoverIO hoverIO) {

    foreach (_; hoverIO) {
        return true;
    }
    return false;

}

/// ditto
bool hovers(HoverIO hoverIO, const Hoverable hoverable) {

    foreach (hovered; hoverIO) {
        if (hovered.opEquals(cast(const Object) hoverable)) return true;
    }

    return false;

}

/// Test if the hover I/O system hovers all of the nodes and none other.
/// Params:
///     hoverIO    = Hover I/O system to test. Hoverables reported by this system will be checked.
///     hoverables = A forward range of hoverables.
/// Returns:
///     True if the system considers all of the given ranges as hovered,
///     and it does not find any other nodes hovered.
bool hoversOnly(Range)(HoverIO hoverIO, Range hoverables) 
if (isForwardRange!Range && is(ElementType!Range : const Hoverable))
do {

    import std.algorithm : canFind;

    foreach (hovered; hoverIO) {

        // A node is hovered, but not in the known list
        if (!hoverables.canFind!((a, b) => a.opEquals(cast(const Object) b))(hovered)) {
            return false;
        }

    }

    foreach (hoverable; hoverables) {

        // A hoverable is not hovered
        if (!hoverIO.hovers(hoverable)) {
            return false;
        }

    }

    return true;

}

/// A pointer is a position on the screen chosen by the user using a mouse, touchpad, touchscreen or other device
/// capable of communicating some position.
///
/// While in a typical desktop application there will usually be a single pointer at a time, there can be cases
/// where there may be none (no mouse connected) or more (multitouch-enabled screen, multiple mouses connected, etc.)
///
/// A pointer is associated with an I/O system that represents the device that invoked the pointer.
/// This may be a dedicated mouse node, but it may also be a generic system that abstracts the device away;
/// for example, Raylib provides a singular function for getting the mouse position without distinguishing
/// between multiple devices or touchscreens.
///
/// For a pointer to work, it has to be loaded into a `HoverIO` system using its `load` method. This has to be done
/// once a frame for as long as the pointer is active. This will be every frame for a mouse (if one is connected),
/// or only the frames a finger is touching the screen for a touchscreen.
///
/// See_Also:
///     `HoverIO`, `HoverIO.load`
struct Pointer {

    /// I/O system that represents the device controlling the pointer.
    IO device;

    /// If the device can control multiple pointers (like a touchscreen), this number should uniquely identify
    /// a pointer.
    int number;

    /// Position in the window the pointer is pointing at.
    Vector2 position;

    /// True if the pointer is not currently pointing, like a finger that stopped touching the screen.
    bool isDisabled;

    /// `HoverIO` system controlling the pointer.
    private HoverIO _hoverIO;

    /// ID of the pointer assigned by the `HoverIO` system.
    private int _id;

    /// Compare two pointers. All publicly exposed fields (`device`, `number`, `position`, `isDisabled`)
    /// must be equal. To check if the two pointers have the same origin (device and number), use `isSame`.
    /// Params:
    ///     other = Pointer to compare against.
    /// Returns: 
    ///     True if the pointer is the same as the other pointer and has the same state.
    bool opEquals(const Pointer other) const {

        // Do not compare I/O metadata
        return isSame(other)
            && position   == other.position
            && isDisabled == other.isDisabled;

    }

    /// Test if the two pointers have the same origin — same device and pointer number.
    /// Params:
    ///     other = Pointer to compare against.
    /// Returns:
    ///     True if the pointers have the same device and pointer number.
    bool isSame(const Pointer other) const {

        if (device is null) {
            return other.device is null
                && number == other.number;
        }

        return device.opEquals(cast(const Object) other.device)
            && number == other.number;

    }

    /// Returns: The ID/index assigned by `HoverIO` when this pointer was loaded.
    int id() const nothrow {
        return this._id;
    }

    /// Load the pointer into the system.
    void load(HoverIO hoverIO, int id) nothrow {
        this._hoverIO = hoverIO;
        this._id = id;
    }

    /// Update a pointer in place using data of another pointer.
    /// Params:
    ///     other = Pointer to copy data from.
    void update(Pointer other) {
        this.position = other.position;
        this.isDisabled = other.isDisabled;
    }

    /// Emit an event through the pointer.
    ///
    /// The device should call this every frame an input event associated with the pointer occurs. This will be
    /// when a mouse button is pressed, every frame a finger touches the screen, or when a gesture recognized
    /// by the device or system is performed.
    ///
    /// Params:
    ///     event = Event to emit.
    ///         The event is usually considered "active" during the frame the action is "released". For example,
    ///         user stops holding a mouse button, or a finger stops touching the screen.
    /// See_Also: 
    ///     `HoverIO.emitEvent`
    void emitEvent(InputEvent event) {

        _hoverIO.emitEvent(this, event);

    }

}

/// Nodes implementing this interface can be selected by a `HoverIO` system.
interface Hoverable : Actionable {

    /// Handle input. Called each frame when focused.
    ///
    /// Do not call this method if the `blocksInput` is true.
    ///
    /// Returns:
    ///     True if hover was handled, false if it was ignored.
    bool hoverImpl()
    in (!blocksInput, "This node currently doesn't accept input.");

    /// Returns: 
    ///     True if this node is hovered.
    ///     This will most of the time be equivalent to `hoverIO.isHovered(this)`, 
    ///     but a node wrapping another hoverable may choose to instead redirect this to the other node.
    bool isHovered() const;

}

/// Create a virtual Hover I/O pointer for testing, and place it at the given position. Interactions on the pointer
/// are asynchronous and should be performed by `then` chains, see `fluid.future.pipe`.
///
/// The pointer is disabled after every interaction, but it will be automatically re-enabled after every movement.
///
/// Params:
///     hoverIO  = Hover I/O system to target.
///     position = Position to place the pointer at. 
PointerAction point(HoverIO hoverIO, Vector2 position) {

    import fluid.node;

    auto action = new PointerAction(hoverIO);
    action.move(position);
    return action;

}

/// Virtual Hover I/O pointer, for testing.
class PointerAction : TreeAction, Publisher!PointerAction {

    import fluid.node;

    public {

        /// Pointer this action operates on.
        Pointer pointer;

    }

    private {

        /// Hover I/O interface the action interacts with.
        HoverIO hoverIO;

        /// Hover I/O casted to a node
        Node _node;

        Event!PointerAction _onInteraction;

    }

    alias then = typeof(super).then;
    alias then = Publisher!PointerAction.then;

    this(HoverIO hoverIO) {

        this.hoverIO = hoverIO;
        this._node = cast(Node) hoverIO;
        assert(_node, "Given Hover I/O is not a valid node");

    }

    void subscribe(Subscriber!PointerAction subscriber) {
        _onInteraction ~= subscriber;
    }

    /// Returns:
    ///     Currently hovered node, if any.
    Hoverable currentHover() {

        hoverIO.loadTo(pointer);
        return hoverIO.hoverOf(pointer);

    }

    /// Don't move the pointer, but keep it active.
    /// Returns: This action, for chaining.
    PointerAction stayIdle() return {

        _node.startAction(this);

        // Place the pointer
        pointer.isDisabled = false;
        hoverIO.loadTo(pointer);

        return this;

    }

    /// Move the pointer to given position.
    /// Params:
    ///     position = Position to move the pointer to.
    /// Returns:
    ///     This action, for chaining.
    PointerAction move(Vector2 position) return {

        _node.startAction(this);

        // Place the pointer
        pointer.isDisabled = false;
        pointer.position = position;
        hoverIO.loadTo(pointer);

        return this;

    }

    /// Run an input action on the currently hovered node, if any.
    /// Params:
    ///     actionID = ID of the action to run.
    ///     isActive = "Active" status of the action.
    /// Returns:
    ///     True if the action was handled, false if not.
    bool runInputAction(immutable InputActionID actionID, bool isActive = true) {

        hoverIO.loadTo(pointer);
        auto hoverable = hoverIO.hoverOf(pointer);

        // Emit a matching, fake hover event
        const code = InputEventCode(ioID!HoverIO, -1);
        const event = InputEvent(code, isActive);
        hoverIO.emitEvent(pointer, event);

        // No hoverable
        if (!hoverable) return false;

        // Can't run the action
        if (hoverable.blocksInput) return false;

        return hoverable.actionImpl(actionID, isActive);

    }

    /// ditto
    bool runInputAction(alias action)(bool isActive = true) {

        alias actionID = inputActionID!action;

        return runInputAction(actionID, isActive);

    }

    /// Shorthand for `runInputAction!(FluidInputAction.press)`
    alias press = runInputAction!(FluidInputAction.press);

    override void stopped() {

        // Disable the pointer
        pointer.isDisabled = true;
        hoverIO.loadTo(pointer);

        _onInteraction(this);

    }

}
