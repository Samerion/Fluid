///
module fluid.hover_chain;

import std.array;
import std.algorithm;

import fluid.node;
import fluid.types;
import fluid.utils;
import fluid.node_chain;

import fluid.io.hover;
import fluid.io.focus;
import fluid.io.action;

import fluid.future.arena;
import fluid.future.action;

@safe:

alias hoverChain = nodeBuilder!HoverChain;

/// A hover chain can be used to separate hover in different areas of the user interface, effectively treating them
/// like separate windows. A device node (like a mouse) can be placed to control nodes inside.
///
/// `HoverChain` has to be placed inside `FocusIO` to enable switching focus by pressing nodes.
///
/// For focus-based nodes like keyboard and gamepad, see `FocusChain`.
///
/// `HoverChain` only works with nodes compatible with the new I/O system introduced in Fluid 0.7.2.
class HoverChain : NodeChain, HoverIO {

    ActionIO actionIO;
    FocusIO focusIO;

    private {

        struct Pointer {

            /// The stored pointer. This is the last pointer assigned by `load`, as given by the device node.
            /// Event handlers are given `armedValue` instead.
            HoverPointer value;

            /// Pointer passed to event handlers. Associated with a negative ID, i.e. if the pointer's ID is `0`,
            /// the ID of `armedValue` is `-1`, if the main ID is `1`, the ID of `armedValue` is `-2` and so on.
            HoverPointer armedValue;

            /// Branch action associated with the pointer; finds the associated node.
            FindHoveredNodeAction action;

            /// Node last matched to the pointer. "Hovered" node.
            Node node;

            /// Node that is being held, placed under the cursor at the time a button has been pressed.
            /// Input actions won't fire if the hovered node, the one under the cursor, is different from the one
            /// that is being held.
            Node heldNode;

            /// Scrollable hovered by this pointer, if any.
            HoverScrollable scrollable;

            /// If true, any button related to the pointer is being held.
            ///
            /// `heldNode` will not be updated while this is true, and current focus will be updated to match
            /// the hovered node.
            bool isHeld;

            /// If true, the pointer already handled incoming input events.
            bool isHandled;

            bool opEquals(const HoverPointer pointer) const {
                return this.value.isSame(pointer);
            }

        }

        ResourceArena!Pointer _pointers;

    }

    this() {

    }

    this(Node next) {
        super(next);
    }

    /// Each `HoverPointer` loaded into `HoverChain` has two values, under two different ID numbers.
    /// This function converts either number into the original one.
    ///
    /// Since the IDs are assigned in a consistent, deterministic manner,
    /// the pointer does not need to be loaded for this function to work.
    ///
    /// See_Also:
    ///     `fetch` for information on the difference between the values.
    ///     `armedPointerID` for a function to get the ID of the armed pointer.
    /// Params:
    ///     number = Pointer ID to normalize, negative or not.
    /// Returns:
    ///     The normalized, non-negative pointer number.
    ///     Returns the same ID as given if it was already normalized.
    int normalizedPointerID(int number) const {

        if (number < 0) {
            return -number - 1;
        }
        else {
            return number;
        }

    }

    /// Performs the opposite of `normalizedPointerID`; gets the ID of the armed pointer, the one made available
    /// to event handling nodes.
    ///
    /// Since the IDs are assigned in a consistent, deterministic manner,
    /// the pointer does not need to be loaded for this function to work.
    ///
    /// See_Also:
    ///     `normalizedPointerID`
    /// Params:
    ///     number = ID of the pointer, either negative or not.
    /// Returns:
    ///     The ID of the armed pointer.
    ///     Returns the same ID as given if it was already armed.
    int armedPointerID(int number) const {

        if (number >= 0) {
            return -number - 1;
        }
        else {
            return number;
        }

    }

    override int load(HoverPointer pointer)
    out(r) {
        import std.format;
        debug assert(_pointers.allResources.count(pointer) == 1,
            format!"Duplicate pointers created: %(\n  %s%)"(_pointers.allResources));
    }
    do {

        const index = cast(int) _pointers.allResources.countUntil(pointer);

        // No such pointer
        if (index == -1) {
            Pointer newPointer;
            newPointer.value = pointer;
            newPointer.armedValue.isDisabled = true;
            newPointer.action = new FindHoveredNodeAction;
            newPointer.action.stop();  // Temporarily mark as inactive

            const newIndex = _pointers.load(newPointer);
            _pointers[newIndex].value.load(this, newIndex);
            return newIndex;
        }

        // Found, update the pointer
        else {
            auto updatedPointer = _pointers[index];
            updatedPointer.value.update(pointer);
            updatedPointer.value.load(this, index);
            _pointers.reload(index, updatedPointer);
            return index;
        }

    }

    /// Fetch a pointer by the number assigned to it when loading.
    ///
    /// Under the hood, `HoverChain` creates two pointers for each load.
    /// One has a number of zero or more (the original pointer), and one has a negative number (armed pointer).
    /// The original pointer reflects the changes made when loading and updating exactly,
    /// while the armed pointer is updated only when a new frame starts.
    /// This makes it possible to update the pointer, while it is in use by `FindHoveredNodeAction`.
    /// Otherwise, the values given to the could be out of date by the time the relevant node is found.
    ///
    /// See_Also:
    ///     `normalizedPointerID` and `armedPointerID` for converting between pointer IDs.
    /// Returns:
    ///     Pointer associated with the node.
    override inout(HoverPointer) fetch(int number) inout {

        // Armed variant
        if (number < 0) {
            const trueNumber = normalizedPointerID(number);
            assert(_pointers.isActive(trueNumber), "Pointer is not active");
            return _pointers[trueNumber].armedValue;
        }

        // Original variant
        else {
            assert(_pointers.isActive(number), "Pointer is not active");
            return _pointers[number].value;
        }

    }

    override void emitEvent(HoverPointer pointer, InputEvent event) {

        const id = normalizedPointerID(pointer.id);

        assert(_pointers.isActive(id), "Pointer is not active");

        // Mark the pointer as held
        _pointers[id].isHeld = true;

        // Emit the event
        if (actionIO) {
            actionIO.emitEvent(event, id, &runInputAction);
        }

    }

    override bool isHovered(const Hoverable hoverable) const {

        foreach (pointer; _pointers.activeResources) {

            // Skip disabled pointers
            if (pointer.value.isDisabled) continue;

            // Check for matches
            if (hoverable.opEquals(pointer.node)) {
                return true;
            }

        }

        return false;

    }

    /// List all active pointers controlled by this `HoverChain`.
    ///
    /// A copy of each pointer is maintained to pass to event handlers. While iterating,
    /// only one version will be passed of each pointer: if while drawing,
    /// the "armed" copy is used, otherwise the regular versions will be returned.
    ///
    /// The above distinction makes it possible for nodes to process the same pointers
    /// as they're given in event handlers, while outsiders are given the usual versions.
    override int opApply(int delegate(HoverPointer) @safe yield) {

        foreach (pointer; _pointers.activeResources) {

            auto value = pointer.action.toStop
                ? pointer.value
                : pointer.armedValue;

            // List each pointer
            if (auto result = yield(value)) {
                return result;
            }

        }

        return 0;

    }

    override int opApply(int delegate(Hoverable) @safe yield) {

        foreach (pointer; _pointers.activeResources) {

            // Skip disabled pointers
            if (pointer.value.isDisabled) continue;

            // List each hoverable
            if (auto hoverable = cast(Hoverable) pointer.node) {
                if (auto result = yield(hoverable)) {
                    return result;
                }
            }

        }

        return 0;

    }

    override void beforeResize(Vector2) {

        use(actionIO);
        use(focusIO);
        _pointers.startCycle();

        auto frame = controlIO!HoverIO();
        frame.start();
        frame.release();

    }

    override void afterResize(Vector2) {

        auto frame = controlIO!HoverIO();
        frame.stop();

    }

    override void beforeDraw(Rectangle outer, Rectangle inner) {

        foreach (resource; _pointers.activeResources) {

            const id = resource.value.id;
            const armedID = armedPointerID(id);

            // Update the pointer when done
            scope (exit) _pointers[id] = resource;

            // Arm the pointer
            resource.armedValue = resource.value;
            resource.armedValue.load(this, armedID);

            if (resource.value.isDisabled) continue;

            // Start the tree action
            resource.action.search = resource.value.position;
            resource.action.scroll = resource.value.scroll;
            auto frame = controlBranchAction(resource.action);
            frame.start();
            frame.release();

        }

    }

    override void afterDraw(Rectangle outer, Rectangle inner) {

        auto frame = controlBranchAction(_pointers.activeResources.map!"a.action");
        frame.stop();

        // Update hover data
        foreach (resource; _pointers.activeResources) {

            const pointer = resource.armedValue;

            // Ignore disabled pointers
            if (pointer.isDisabled) continue;

            const id = resource.value.id;
            const armedID = pointer.id;
            assert(armedID < 0);

            scope (exit) _pointers[id] = resource;

            // Keep the same hovered node if the pointer is being held,
            // otherwise switch.
            resource.node = resource.action.result;
            if (!resource.isHeld) {
                resource.heldNode = resource.node;
            }

            // Switch focus to hovered node if holding
            else if (focusIO) {
                if (auto focusable = resource.heldNode.castIfAcceptsInput!Focusable) {
                    if (!focusable.isFocused) {
                        focusable.focus();
                    }
                }
                else {
                    focusIO.clearFocus();
                }
            }

            // Update scroll and send new events
            if (!pointer.isScrollHeld) {
                resource.scrollable = resource.action.scrollable;
            }
            if (resource.scrollable) {
                resource.scrollable.scrollImpl(pointer.scroll);
            }

            // Reset state
            resource.isHeld = false;
            resource.isHandled = false;

            // Send a frame event to trigger hoverImpl
            if (actionIO) {
                actionIO.emitEvent(ActionIO.frameEvent, armedID, &runInputAction);
            }
            else if (auto hoverable = resource.node.castIfAcceptsInput!Hoverable) {
                resource.isHandled = hoverable.hoverImpl();
            }

        }

    }

    override inout(Hoverable) hoverOf(HoverPointer pointer) inout {
        const id = normalizedPointerID(pointer.id);
        debug assert(_pointers.isActive(id), "Given pointer wasn't loaded");
        return _pointers[id].heldNode.castIfAcceptsInput!Hoverable;
    }

    override inout(HoverScrollable) scrollOf(HoverPointer pointer) inout {
        const id = normalizedPointerID(pointer.id);
        debug assert(_pointers.isActive(id), "Given pointer wasn't loaded");
        return _pointers[id].scrollable;
    }

    /// Handle an input action associated with a pointer.
    /// Params:
    ///     pointer  = Pointer to send the input action. It must be loaded.
    ///         The input action will be loaded by the node the pointer points at.
    ///     actionID = ID of the input action.
    ///     isActive = If true, the action has been activated during this frame.
    /// Returns:
    ///     True if the input action was handled.
    bool runInputAction(HoverPointer pointer, InputActionID actionID, bool isActive = true) {

        const id = normalizedPointerID(pointer.id);
        const armedID = -id - 1;

        auto hover = hoverOf(pointer);
        auto meta = _pointers[id];

        // Active input actions can only fire if `heldNode` is still hovered
        if (isActive) {
            if (meta.node is null || !meta.node.opEquals(meta.heldNode)) {
                return false;
            }
        }

        // Try to handle the action
        const handled =

            // Try to run the action
            (hover && hover.actionImpl(this, armedID, actionID, isActive))

            // Run local input actions as fallback
            || runLocalInputActions(pointer, actionID, isActive)

            // Run hoverImpl as a last resort
            || (actionID == inputActionID!(ActionIO.CoreAction.frame) && hover && hover.hoverImpl());

        // Mark as handled, if so
        _pointers[id].isHandled = meta.isHandled || handled;

        return handled;

    }

    /// ditto
    bool runInputAction(alias action)(HoverPointer pointer, bool isActive = true) {

        const id = inputActionID!action;

        return runInputAction(pointer, id, isActive);

    }

    /// ditto
    protected final bool runInputAction(InputActionID actionID, bool isActive, int number) {

        auto pointer = fetch(number);
        return runInputAction(pointer, actionID, isActive);

    }

    /// Run an input action implemented by this node. `HoverChain` does not implement any by default.
    /// Params:
    ///     pointer  = Pointer associated with the event.
    ///     actionID = ID of the input action to perform.
    ///     isActive = If true, the action has been activated during this frame.
    /// Returns:
    ///     True if the action was handled, false if not.
    protected bool runLocalInputActions(HoverPointer pointer, InputActionID actionID,
        bool isActive = true)
    do {

        return false;

    }

}
