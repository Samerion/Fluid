/// This module implements interfaces for handling hover and connecting hoverable nodes with input devices.
module fluid.io.hover;

import optional;

import std.range;

import fluid.tree;
import fluid.types;

import fluid.future.pipe;
import fluid.future.context;
import fluid.future.branch_action;

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

    /// Fetch a pointer from a number assigned to it by this I/O. This is used by `Actionable` nodes to find
    /// `Pointer` data corresponding to fired input action events.
    ///
    /// The pointer, and the matching number, must be valid.
    ///
    /// Params:
    ///     number = Number assigned to the pointer by this I/O.
    /// Returns:
    ///     The pointer.
    inout(Pointer) fetch(int number) inout;

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
    /// See_Also:
    ///     `scrollOf` to get the current scrollable node.
    inout(Hoverable) hoverOf(Pointer pointer) inout;

    /// Params:
    ///     pointer = Pointer to query. The pointer must be loaded.
    /// Returns:
    ///     Scrollable ancestor for the currently hovered node.
    /// See_Also:
    ///     `hoverOf` to get the currently hovered node.
    inout(HoverScrollable) scrollOf(Pointer pointer) inout;

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

    /// Current scroll value. For a mouse, this indicates mouse wheel movement, for other devices like touchpad or
    /// touchscreen, this will be translated from its movement.
    ///
    /// While it is possible to read scroll of the `Pointer` data received in an input action handler,
    /// it is recommended to implement scroll through `Scrollable.scrollImpl`.
    ///
    /// Scroll is exposed for both the horizontal and vertical axis. While a typical mouse wheel only supports
    /// vertical movement, touchscreens, touchpads, trackpads or more advanced mouses do support horizontal movement.
    /// It is also possible for a device to perform both horizontal and vertical movement at once.
    Vector2 scroll;

    /// If true, the scroll control is held, like a finger swiping through the screen. This does not apply to mouse
    /// wheels.
    ///
    /// If scroll is "held," the scrolling motion should detach from pointer position. Whatever scrollable was
    /// selected at the time scroll was pressed should continue to be selected while held even if the pointer moves
    /// away from it. This makes it possible to comfortably scroll with a touchscreen without having to mind node
    /// boundaries, or to implement features such as [autoscroll].
    ///
    /// [autoscroll]: (https://chromewebstore.google.com/detail/autoscroll/occjjkgifpmdgodlplnacmkejpdionan)
    bool isScrollHeld;

    /// True if the pointer is not currently pointing, like a finger that stopped touching the screen.
    bool isDisabled;

    /// `HoverIO` system controlling the pointer.
    private HoverIO _hoverIO;

    /// ID of the pointer assigned by the `HoverIO` system.
    private int _id;

    /// Create a new pointer.
    /// Params:
    ///     device     = I/O system representing the device that created the pointer.
    ///     number     = Pointer number as assigned by the device.
    ///     position   = Position of the pointer.
    ///     isDisabled = If true, disable the node.
    this(inout IO device, int number, Vector2 position, Vector2 scroll = Vector2.init, bool isDisabled = false) inout {
        this.device     = device;
        this.number     = number;
        this.position   = position;
        this.scroll     = scroll;
        this.isDisabled = isDisabled;
    }

    /// Create a new pointer.
    /// Params:
    ///     position   = Position of the pointer.
    this(Vector2 position) {
        this.position = position;
    }

    /// If the given system is a Hover I/O system, fetch a pointer.
    ///
    /// Given data must be valid; the I/O must be a `HoverIO` instance and the number must be a valid pointer number.
    ///
    /// Params:
    ///     io     = I/O system to use.
    ///     number = Valid pointer number assigned by the I/O system.
    /// Returns:
    ///     Pointer under given number.
    static Optional!Pointer fetch(IO io, int number) {

        import std.format;

        if (auto hoverIO = cast(HoverIO) io) {
            return typeof(return)(
                hoverIO.fetch(number));
        }

        return typeof(return).init;

    }

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
        this.position     = other.position;
        this.scroll       = other.scroll;
        this.isScrollHeld = other.isScrollHeld;
        this.isDisabled   = other.isDisabled;
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

/// Nodes implementing this interface can react to scroll motion if selected by a `HoverIO` system.
///
/// Temporarily called `HoverScrollable`, this node will be renamed to `Scrollable` in a future release.
/// https://git.samerion.com/Samerion/Fluid/issues/278
interface HoverScrollable {

    import fluid.node;

    /// Controls whether this node can accept scroll input and the input can have visible effect. This is usually
    /// determined by the node's position; for example a container node already scrolled to the bottom cannot accept
    /// further vertical movement down.
    ///
    /// This property is used to determine which node should be used to accept scroll. If there's a scrollable
    /// container nested in another scrollable node, it will be chosen for scrolling only if the scroll motion
    /// can still be performed. On the other hand, if the intent is specifically to block scroll motion (like in
    /// a modal window), this method should always return true.
    ///
    /// Note that a node "can scroll" even if it can only accept part of the motion. If the scroll would have
    /// the node scroll beyond its maximum value, but the node is not already at its maximum, it should accept
    /// the input and clamp the value.
    ///
    /// Params:
    ///     value = Input scroll value for both X and Y axis. This corresponds to the screen distance the scroll
    ///         motion should cover.
    /// Returns:
    ///     True if the node can accept the scroll value in part or in whole,
    ///     false if the motion would have no effect.
    bool canScroll(Vector2 value) const;

    /// Perform a scroll motion, moving the node's contents by the specified distance.
    ///
    /// At the moment this function returns `void` for backwards compatibility. This will change in the future
    /// into a boolean value, indicating if the motion was handled or not.
    ///
    /// Params:
    ///     value = Value to scroll the contents by.
    void scrollImpl(Vector2 value);

    /// Scroll towards a specified child node, trying to get it into view.
    ///
    /// Params:
    ///     child     = Target node, a child of this node. Ideally, this node should appear on screen as a consequence.
    ///     parentBox = Padding box of this node, the node performing the scroll.
    ///     childBox  = Known padding box of the target child node.
    /// Returns:
    ///     A new padding box for the child node after applying scroll.
    Rectangle shallowScrollTo(const Node child, Rectangle parentBox, Rectangle childBox);

    /// Memory safe and `const` object comparison.
    /// Returns:
    ///     True if this, and the other object, are the same object.
    /// Params:
    ///     other = Object to compare to.
    bool opEquals(const Object other) const;

}

/// Cast the node to given type if it accepts scroll.
///
/// In addition to performing a dynamic cast, this checks if the node can handle a specified scroll value
/// according to its `HoverScrollable.canScroll` method.
/// If it doesn't, it will fail the cast.
///
/// Params:
///     node = Node to cast.
/// Returns:
///     Node casted to `Scrollable`, or null if the node can't be casted, or the motion would not have effect.
inout(HoverScrollable) castIfAcceptsScroll(inout Object node, Vector2 value) {

    // Perform the cast
    if (auto scrollable = cast(inout HoverScrollable) node) {

        // Node must accept scroll
        if (scrollable.canScroll(value)) {
            return scrollable;
        }

    }

    return null;

}

/// Find the topmost node that occupies the given position on the screen.
///
/// The result may change while the search runs; the final result is available once the action stops.
/// On top of finding the node at specified position, a scroll value can be passed so this action will also find
/// any `Scrollable` ancestor present in the branch, if one can handle the motion.
/// If the resulting node is scrollable, it may be returned.
///
/// For backwards compatibility, this node is not currently registered as a `NodeSearchAction` and does not emit
/// a node when done.
final class FindHoveredNodeAction : BranchAction {

    import fluid.node;

    public {

        /// If a node was found, this is the result.
        Node result;

        /// Topmost scrollable ancestor of `result` (the chosen node).
        HoverScrollable scrollable;

        /// Position that is looked up.
        Vector2 search;

        /// Scroll value to test `scrollable` against. If the scroll motion with this value would not have effect
        /// on a scrollable, it will not be chosen.
        Vector2 scroll;

    }

    this(Vector2 search = Vector2.init, Vector2 scroll = Vector2.init) {
        this.search = search;
        this.scroll = scroll;
    }

    override void started() {
        super.started();
        this.result = null;
        this.scrollable = null;
    }

    /// Test if the searched position is within the bounds of this node, and set it as the result if so.
    /// Any previously found result is overridden.
    ///
    /// If a node is found, `scrollable` is cleared. A new one will be found in `afterDraw`.
    ///
    /// Because of how layering works in Fluid, the last node in bounds will be the result. This action cannot quit
    /// early as any node can override the current hover.
    override void beforeDraw(Node node, Rectangle, Rectangle outer, Rectangle inner) {

        // Check if the position is in bounds of the node
        if (!node.inBounds(outer, inner, search)) return;

        // Save the result
        result = node;

        // Clear scrollable
        scrollable = null;

        // Do not stop; the result may be overridden

    }

    /// Find a matching scrollable for the node. The topmost ancestor of `result` (the chosen node) will be used.
    override void afterDraw(Node node, Rectangle) {

        // A result is required and no scrollable could have matched already
        if (result is null) return;
        if (scrollable) return;

        // Try to match this node
        scrollable = node.castIfAcceptsScroll(scroll);

    }

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

/// ditto
PointerAction point(HoverIO hoverIO, float x, float y) {

    return point(hoverIO, Vector2(x, y));

}

/// Virtual Hover I/O pointer, for testing.
class PointerAction : TreeAction, Publisher!PointerAction, IO {

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
        this.pointer.device = this;
        assert(_node, "Given Hover I/O is not a valid node");

    }

    override bool opEquals(const Object other) const {
        return this is other;
    }

    override inout(TreeContext) treeContext() inout {
        return hoverIO.treeContext;
    }

    void subscribe(Subscriber!PointerAction subscriber) {
        _onInteraction ~= subscriber;
    }

    override void clearSubscribers() {
        super.clearSubscribers();
        _onInteraction.clearSubscribers();
    }

    /// Returns:
    ///     Currently hovered node, if any.
    Hoverable currentHover() {

        hoverIO.loadTo(pointer);
        return hoverIO.hoverOf(pointer);

    }

    /// Returns:
    ///     Chosen scrollable, if any.
    HoverScrollable currentScroll() {

        hoverIO.loadTo(pointer);
        return hoverIO.scrollOf(pointer);

    }

    /// Returns: True if the given node is hovered.
    bool isHovered(const Hoverable hoverable) {

        if (hoverable is null)
            return currentHover is null;
        else
            return currentHover && currentHover.opEquals(cast(const Object) hoverable);

    }

    /// Don't move the pointer, but keep it active.
    /// Returns: This action, for chaining.
    PointerAction stayIdle() return {

        clearSubscribers();
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

        clearSubscribers();
        _node.startAction(this);

        // Place the pointer
        pointer.isDisabled = false;
        pointer.position = position;
        hoverIO.loadTo(pointer);

        return this;

    }

    /// ditto
    PointerAction move(float x, float y) return {

        return move(Vector2(x, y));

    }

    /// Set a scroll value for the action.
    ///
    /// Once the motion is completed, the scroll value will be reset and will not apply for future actions.
    ///
    /// Params:
    ///     motion = Distance to scroll.
    /// Returns:
    ///     This action, for chaining.
    PointerAction scroll(Vector2 motion) return {

        clearSubscribers();
        _node.startAction(this);

        // Place the pointer
        pointer.isDisabled = false;
        pointer.scroll = motion;
        hoverIO.loadTo(pointer);

        return this;

    }

    /// ditto
    PointerAction scroll(float x, float y) return {

        return scroll(Vector2(x, y));

    }

    /// Hold the scroll control in place. This makes it possible to continue scrolling a single node while
    /// moving the cursor, which is commonly the scrolling behavior of touchscreens.
    ///
    /// The hold status will be reset after a frame.
    void holdScroll(bool value = true) return {

        pointer.isScrollHeld = value;
        hoverIO.loadTo(pointer);

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

        return hoverable.actionImpl(hoverIO, pointer.id, actionID, isActive);

    }

    /// ditto
    bool runInputAction(alias action)(bool isActive = true) {

        alias actionID = inputActionID!action;

        return runInputAction(actionID, isActive);

    }

    /// Shorthand for `runInputAction!(FluidInputAction.press)`
    alias press = runInputAction!(FluidInputAction.press);

    override void beforeDraw(Node node, Rectangle) {

        // Make sure the pointer is loaded and up to date
        // If the action was scheduled before a resize, the pointer would die during it
        if (hoverIO.opEquals(node)) {
            hoverIO.loadTo(pointer);
        }

    }

    override void stopped() {

        super.stopped();

        // Disable the pointer and clear scroll
        pointer.isDisabled = true;
        pointer.scroll = Vector2();
        pointer.isScrollHeld = false;
        hoverIO.loadTo(pointer);

        _onInteraction(this);

    }

}
