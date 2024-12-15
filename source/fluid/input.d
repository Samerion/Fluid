///
module fluid.input;

import std.meta;
import std.format;
import std.traits;
import std.algorithm;

import fluid.node;
import fluid.tree;
import fluid.style;
import fluid.backend;

import fluid.io.focus;
import fluid.io.hover;
import fluid.io.action;


@safe:


/// Make a InputAction handler react to every frame as long as the action is being held (mouse button held down,
/// key held down, etc.).
enum WhileHeld;

alias WhileDown = WhileHeld;

deprecated ("`whileDown` has been deprecated and will be removed in Fluid 0.8.0. Use `WhileDown` instead.")
alias whileDown = WhileDown;

/// Default input actions one can listen to.
@InputAction
enum FluidInputAction {

    // Basic
    press,       /// Press the input. Used for example to activate buttons.
    submit,      /// Submit input, eg. finish writing in textInput.
    cancel,      /// Cancel the input.
    contextMenu, /// Open context menu.

    // Focus
    focusPrevious,  /// Focus previous input.
    focusNext,      /// Focus next input.
    focusLeft,      /// Focus input on the left.
    focusRight,     /// Focus input on the right.
    focusUp,        /// Focus input above.
    focusDown,      /// Focus input below.

    // Text navigation
    breakLine,      /// Start a new text line, place a line feed.
    previousChar,   /// Move to the previous character in text.
    nextChar,       /// Move to the next character in text.
    previousWord,   /// Move to the previous word in text.
    nextWord,       /// Move to the next word in text.
    previousLine,   /// Move to the previous line in text.
    nextLine,       /// Move to the next line in text.
    toLineStart,    /// Move to the beginning of this line; Home key.
    toLineEnd,      /// Move to the end of this line; End key.
    toStart,        /// Move to the beginning.
    toEnd,          /// Move to the end.

    // Editing
    backspace,      /// Erase last character in an input.
    backspaceWord,  /// Erase last a word in an input.
    deleteChar,     /// Delete the next character in an input
    deleteWord,     /// Delete the next word in an input
    copy,           /// Copy selected content.
    cut,            /// Cut (copy and delete) selected content.
    paste,          /// Paste selected content.
    undo,           /// Undo last action.
    redo,           /// Redo last action; Reverse "undo".
    insertTab,      /// Insert a tab into a code editor (tab key)
    indent,         /// Indent current line or selection in a code editor.
    outdent,        /// Outdent current line or selection in a code editor (shift+tab).

    // Selection
    selectPreviousChar,  /// Select previous character in text.
    selectNextChar,      /// Select next character in text.
    selectPreviousWord,  /// Select previous word in text.
    selectNextWord,      /// Select next word in text.
    selectPreviousLine,  /// Select to previous line in text.
    selectNextLine,      /// Select to next line in text.
    selectAll,           /// Select all in text.
    selectToLineStart,   /// Select from here to line beginning.
    selectToLineEnd,     /// Select from here to line end.
    selectToStart,       /// Select from here to beginning.
    selectToEnd,         /// Select from here to end.

    // List navigation
    entryPrevious,  /// Navigate to the previous list entry.
    entryNext,      /// Navigate to the next list entry.
    entryUp,        /// Navigate up in a tree, eg. in the file picker.

    // Scrolling
    scrollLeft,     /// Scroll left a bit.
    scrollRight,    /// Scroll right a bit.
    scrollUp,       /// Scroll up a bit.
    scrollDown,     /// Scroll down a bit
    pageLeft,       /// Scroll left by a page. Unbound by default.
    pageRight,      /// Scroll right by a page. Unbound by default.
    pageUp,         /// Scroll up by a page.
    pageDown,       /// Scroll down by a page.

}

/// ID of an input action.
immutable struct InputActionID {

    /// Unique ID of the action.
    size_t id;

    /// Action name. Only emitted when debugging.
    debug string name;

    /// Get ID of an input action.
    this(IA : InputAction!actionType, alias actionType)(IA) immutable {

        this.id = cast(size_t) &IA._id;
        debug this.name = fullyQualifiedName!(IA.type);

    }

    static InputActionID from(alias item)() {

        return InputAction!item.id;

    }

    bool opEqual(InputActionID other) {

        return id == other.id;

    }

}

enum isInputActionType(alias actionType) = isInputAction!actionType;

unittest {

    enum MyEnum {
        foo = 123,
    }

    @InputAction
    enum MyAction {
        foo,
    }

    static assert(isInputActionType!(FluidInputAction.entryUp));
    static assert(isInputActionType!(MyAction.foo));

    static assert(!isInputActionType!InputNode);
    static assert(!isInputActionType!InputAction);
    static assert(!isInputActionType!(InputAction!(FluidInputAction.entryUp)));
    static assert(!isInputActionType!FluidInputAction);
    static assert(!isInputActionType!MyEnum);
    static assert(!isInputActionType!(MyEnum.foo));
    static assert(!isInputActionType!MyAction);


}

/// Represents a key or button input combination.
struct InputStroke {

    import std.sumtype;

    alias Item = SumType!(KeyboardKey, MouseButton, GamepadButton);

    Item[] input;

    this(T...)(T items)
    if (!is(items : Item[])) {

        input.length = items.length;
        static foreach (i, item; items) {

            input[i] = Item(item);

        }

    }

    this(Item[] items) {

        input = items;

    }

    /// Get number of items in the stroke.
    size_t length() const {
        return input.length;
    }

    /// Get a copy of the input stroke with the last item removed, if any.
    ///
    /// For example, for a `leftShift+w` stroke, this will return `leftShift`.
    InputStroke modifiers() {

        return input.length
            ? InputStroke(input[0..$-1])
            : InputStroke();

    }

    /// Check if the last item of this input stroke is done with a mouse
    bool isMouseStroke() const {

        return isMouseItem(input[$-1]);

    }

    unittest {

        assert(!InputStroke(KeyboardKey.leftControl).isMouseStroke);
        assert(!InputStroke(KeyboardKey.w).isMouseStroke);
        assert(!InputStroke(KeyboardKey.leftControl, KeyboardKey.w).isMouseStroke);

        assert(InputStroke(MouseButton.left).isMouseStroke);
        assert(InputStroke(KeyboardKey.leftControl, MouseButton.left).isMouseStroke);

        assert(!InputStroke(GamepadButton.triangle).isMouseStroke);
        assert(!InputStroke(KeyboardKey.leftControl, GamepadButton.triangle).isMouseStroke);

    }

    /// Check if the given item is done with a mouse.
    static bool isMouseItem(Item item) {

        return item.match!(
            (MouseButton _) => true,
            (_) => false,
        );

    }

    /// Check if all keys or buttons required for the stroke are held down.
    bool isDown(const FluidBackend backend) const {

        return input.all!(a => isItemDown(backend, a));

    }

    ///
    unittest {

        auto stroke = InputStroke(KeyboardKey.leftControl, KeyboardKey.w);
        auto io = new HeadlessBackend;

        // No keys pressed
        assert(!stroke.isDown(io));

        // Control pressed
        io.press(KeyboardKey.leftControl);
        assert(!stroke.isDown(io));

        // Both keys pressed
        io.press(KeyboardKey.w);
        assert(stroke.isDown(io));

        // Still pressed, but not immediately
        io.nextFrame;
        assert(stroke.isDown(io));

        // W pressed
        io.release(KeyboardKey.leftControl);
        assert(!stroke.isDown(io));

    }

    /// Check if the stroke has been triggered during this frame.
    ///
    /// If the last item of the action is a mouse button, the action will be triggered on release. If it's a keyboard
    /// key or gamepad button, it'll be triggered on press. All previous items, if present, have to be held down at the
    /// time.
    bool isActive(const FluidBackend backend) const @trusted {

        // For all but the last item, check if it's held down
        return input[0 .. $-1].all!(a => isItemDown(backend, a))

            // For the last item, check if it's pressed or released, depending on the type
            && isItemActive(backend, input[$-1]);

    }

    unittest {

        auto singleKey = InputStroke(KeyboardKey.w);
        auto stroke = InputStroke(KeyboardKey.leftControl, KeyboardKey.leftShift, KeyboardKey.w);
        auto io = new HeadlessBackend;

        // No key pressed
        assert(!singleKey.isActive(io));
        assert(!stroke.isActive(io));

        io.press(KeyboardKey.w);

        // Just pressed the "W" key
        assert(singleKey.isActive(io));
        assert(!stroke.isActive(io));

        io.nextFrame;

        // The stroke stops being active on the next frame
        assert(!singleKey.isActive(io));
        assert(!stroke.isActive(io));

        io.press(KeyboardKey.leftControl);
        io.press(KeyboardKey.leftShift);

        assert(!singleKey.isActive(io));
        assert(!stroke.isActive(io));

        // The last key needs to be pressed during the current frame
        io.press(KeyboardKey.w);

        assert(singleKey.isActive(io));
        assert(stroke.isActive(io));

        io.release(KeyboardKey.w);

        assert(!singleKey.isActive(io));
        assert(!stroke.isActive(io));

    }

    /// Mouse actions are activated on release
    unittest {

        auto stroke = InputStroke(KeyboardKey.leftControl, MouseButton.left);
        auto io = new HeadlessBackend;

        assert(!stroke.isActive(io));

        io.press(KeyboardKey.leftControl);
        io.press(MouseButton.left);

        assert(!stroke.isActive(io));

        io.release(MouseButton.left);

        assert(stroke.isActive(io));

        // The action won't trigger if previous keys aren't held down
        io.release(KeyboardKey.leftControl);

        assert(!stroke.isActive(io));

    }

    /// Check if the given is held down.
    static bool isItemDown(const FluidBackend backend, Item item) {

        return item.match!(

            // Keyboard
            (KeyboardKey key) => backend.isDown(key),

            // A released mouse button also counts as down for our purposes, as it might trigger the action
            (MouseButton button) => backend.isDown(button) || backend.isReleased(button),

            // Gamepad
            (GamepadButton button) => backend.isDown(button) != 0
        );

    }

    /// Check if the given item is triggered.
    ///
    /// If the item is a mouse button, it will be triggered on release. If it's a keyboard key or gamepad button, it'll
    /// be triggered on press.
    static bool isItemActive(const FluidBackend backend, Item item) {

        return item.match!(
            (KeyboardKey key) => backend.isPressed(key) || backend.isRepeated(key),
            (MouseButton button) => backend.isReleased(button),
            (GamepadButton button) => backend.isPressed(button) || backend.isRepeated(button),
        );

    }

    string toString()() const {

        return format!"InputStroke(%(%s + %))"(input);

    }

}

/// Binding of an input stroke to an input action.
struct InputBinding {

    InputActionID action;
    InputStroke.Item trigger;

}

/// A layer groups input bindings by common key modifiers.
struct InputLayer {

    InputStroke modifiers;
    InputBinding[] bindings;

    /// When sorting ascending, the lowest value is given to the InputLayer with greatest number of bindings
    int opCmp(const InputLayer other) const {

        // You're not going to put 2,147,483,646 modifiers in a single input stroke, are you?
        return cast(int) (other.modifiers.length - modifiers.length);

    }

}

/// This meta-UDA can be attached to an enum, so Fluid would recognize members of said enum as an UDA defining input
/// actions. As an UDA, this template should be used without instantiating.
///
/// This template also serves to provide unique identifiers for each action type, generated on startup. For example,
/// `InputAction!(FluidInputAction.press).id` will have the same value anywhere in the program.
///
/// Action types are resolved at compile-time using symbols, so you can supply any `@InputAction`-marked enum defining
/// input actions. All built-in enums are defined in `FluidInputAction`.
///
/// If the method returns `true`, it is understood that the action has been processed and no more actions will be
/// emitted during the frame. If it returns `false`, other actions and keyboardImpl will be tried until any call returns
/// `true` or no handlers are left.
struct InputAction(alias actionType)
if (isInputActionType!actionType) {

    alias type = actionType;

    alias id this;

    /// **The pointer** to `_id` serves as ID of the input actions.
    ///
    /// Note: we could be directly getting the address of the ID function itself (`&id`), but it's possible some linkers
    /// would merge declarations, so we're using `&_id` for safety. Example of such behavior can be achieved using
    /// `ld.gold` with `--icf=all`. It's possible the linker could be aware we're checking the function address
    // (`--icf=safe` works correctly), but again, we prefer to play it safe. Alternatively, we could test for this
    /// behavior when the program starts, but it probably isn't worth it.
    align(1)
    private static immutable bool _id;

    static InputActionID id() {

        return InputActionID(typeof(this)());

    }

}

unittest {

    assert(InputAction!(FluidInputAction.press).id == InputAction!(FluidInputAction.press).id);
    assert(InputAction!(FluidInputAction.press).id != InputAction!(FluidInputAction.entryUp).id);

    // IDs should have the same equality as the enum members, within the same enum
    // This will not be the case for enum values with explicitly assigned values (but probably should be!)
    foreach (left; EnumMembers!FluidInputAction) {

        foreach (right; EnumMembers!FluidInputAction) {

            if (left == right)
                assert(InputAction!left.id == InputAction!right.id);
            else
                assert(InputAction!left.id != InputAction!right.id);

        }

    }

    // Enum values don't have to have globally unique
    @InputAction
    enum FooActions {
        action = 0,
    }

    @InputAction
    enum BarActions {
        action = 0,
    }

    assert(InputAction!(FooActions.action).id == InputAction!(FooActions.action).id);
    assert(InputAction!(FooActions.action).id != InputAction!(BarActions.action).id);
    assert(InputAction!(FooActions.action).id != InputAction!(FluidInputAction.press).id);
    assert(InputAction!(BarActions.action).id != InputAction!(FluidInputAction.press).id);

}

@system
unittest {

    import std.concurrency;

    // IDs are global across threads
    auto t0 = InputAction!(FluidInputAction.press).id;

    spawn({

        ownerTid.send(InputAction!(FluidInputAction.press).id);

        spawn({

            ownerTid.send(InputAction!(FluidInputAction.press).id);

        });

        ownerTid.send(receiveOnly!InputActionID);

        ownerTid.send(InputAction!(FluidInputAction.cancel).id);

    });

    auto t1 = receiveOnly!InputActionID;
    auto t2 = receiveOnly!InputActionID;

    auto c0 = InputAction!(FluidInputAction.cancel).id;
    auto c1 = receiveOnly!InputActionID;

    assert(t0 == t1);
    assert(t1 == t2);

    assert(c0 != t0);
    assert(c1 != t1);
    assert(c0 != t1);
    assert(c1 != t0);

    assert(t0 == t1);

}

/// Check if any stroke bound to this action is being held.
bool isDown(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return tree.downActions[].canFind!"a.action == b"(InputActionID.from!type);

}

unittest {

    import fluid.space;

    auto io = new HeadlessBackend;
    auto tree = new LayoutTree(vspace(), io);

    // Nothing pressed, action not activated
    assert(!tree.isDown!(FluidInputAction.backspaceWord));

    version (OSX) 
        io.press(KeyboardKey.leftOption);
    else 
        io.press(KeyboardKey.leftControl);
    io.press(KeyboardKey.backspace);
    tree.poll();

    // The action is now held down with the ctrl+blackspace stroke
    assert(tree.isDown!(FluidInputAction.backspaceWord));

    io.release(KeyboardKey.backspace);
    version (OSX) {
        io.release(KeyboardKey.leftOption);
        io.press(KeyboardKey.leftControl);
    }
    io.press(KeyboardKey.w);
    tree.poll();

    // ctrl+W also activates the stroke
    assert(tree.isDown!(FluidInputAction.backspaceWord));

    io.release(KeyboardKey.leftControl);
    tree.poll();

    // Control up, won't match any stroke now
    assert(!tree.isDown!(FluidInputAction.backspaceWord));

}

/// Check if a mouse stroke bound to this action is being held.
bool isMouseDown(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return tree.downActions[].canFind!(a
        => a.action == InputActionID.from!type
        && InputStroke.isMouseItem(a.trigger));

}

unittest {

    import fluid.space;

    auto io = new HeadlessBackend;
    auto tree = new LayoutTree(vspace(), io);

    assert(!tree.isDown!(FluidInputAction.press));

    io.press(MouseButton.left);
    tree.poll();

    // Pressing with a mouse
    assert(tree.isDown!(FluidInputAction.press));
    assert(tree.isMouseDown!(FluidInputAction.press));

    io.release(MouseButton.left);
    tree.poll();

    // Releasing a mouse key still counts as holding it down
    // This is important — a released mouse is used to trigger the action
    assert(tree.isDown!(FluidInputAction.press));
    assert(tree.isMouseDown!(FluidInputAction.press));

    // Need to wait a frame
    io.nextFrame;
    tree.poll();

    assert(!tree.isDown!(FluidInputAction.press));

    io.press(KeyboardKey.enter);
    tree.poll();

    // Pressing with a keyboard
    assert(tree.isDown!(FluidInputAction.press));
    assert(!tree.isMouseDown!(FluidInputAction.press));

    io.release(KeyboardKey.enter);
    tree.poll();

    assert(!tree.isDown!(FluidInputAction.press));

}

/// Check if a keyboard or gamepad stroke bound to this action is being held.
bool isFocusDown(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return tree.downActions[].canFind!(a
        => a.action == InputActionID.from!type
        && !InputStroke.isMouseItem(a.trigger));

}

unittest {

    import fluid.space;

    auto io = new HeadlessBackend;
    auto tree = new LayoutTree(vspace(), io);

    assert(!tree.isDown!(FluidInputAction.press));

    io.press(KeyboardKey.enter);
    tree.poll();

    // Pressing with a keyboard
    assert(tree.isDown!(FluidInputAction.press));
    assert(tree.isFocusDown!(FluidInputAction.press));

    io.release(KeyboardKey.enter);
    io.press(MouseButton.left);
    tree.poll();

    // Pressing with a mouse
    assert(tree.isDown!(FluidInputAction.press));
    assert(!tree.isFocusDown!(FluidInputAction.press));

}

/// Check if any stroke bound to this action is active.
bool isActive(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return tree.activeActions[].canFind!(a
        => a.action == InputActionID.from!type);

}

/// Check if a mouse stroke bound to this action is active
bool isMouseActive(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return tree.activeActions[].canFind!(a
        => a.action == InputActionID.from!type
        && InputStroke.isMouseItem(a.trigger));

}

/// Check if a keyboard or gamepad stroke bound to this action is active.
bool isFocusActive(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return tree.activeActions[].canFind!(a
        => a.action == InputActionID.from!type
        && !InputStroke.isMouseItem(a.trigger));

}

/// An interface to be implemented by all nodes that can perform actions when hovered (eg. on click)
interface FluidHoverable {

    /// Handle mouse input on the node.
    void mouseImpl();

    /// Check if the node is disabled. `mixin makeHoverable` to implement.
    ref inout(bool) isDisabled() inout;

    /// Check if the node is hovered.
    bool isHovered() const;

    /// Get the underlying node.
    final inout(Node) asNode() inout {

        return cast(inout Node) this;

    }

    /// Handle input actions. This function is called by `runInputAction` and can be overriden to preprocess input
    /// actions in some cases.
    ///
    /// Example: Override a specific action by running a different input action.
    ///
    /// ---
    /// override bool inputActionImpl(InputActionID id, bool active) {
    ///
    ///     if (active && id == InputActionID.from!(FluidInputAction.press)) {
    ///
    ///         return runInputAction!(FluidInputAction.press);
    ///
    ///     }
    ///
    ///     return false;
    ///
    /// }
    /// ---
    ///
    /// Params:
    ///     id     = ID of the action to run.
    ///     active = Actions trigger many times while the corresponding key or button is held down, but usually only one
    ///         of these triggers is interesting — in which case this value will be `true`. This trigger will be the one
    ///         that runs all UDA handler functions.
    /// Returns:
    ///     * `true` if the handler took care of the action; processing of the action will finish.
    ///     * `false` if the action should be handled by the default input action handler.
    bool inputActionImpl(immutable InputActionID id, bool active);

    /// Run input actions.
    ///
    /// Use `mixin enableInputActions` to implement.
    ///
    /// Manual implementation is discouraged; override `inputActionImpl` instead.
    bool runInputActionImpl(immutable InputActionID action, bool active = true);

    final bool runInputAction(immutable InputActionID action, bool active = true) {

        return runInputActionImpl(action, active);

    }

    final bool runInputAction(alias action)(bool active = true) {

        return runInputActionImpl(InputActionID.from!action, active);

    }

    /// Run mouse input actions for the node.
    ///
    /// Internal. `Node` calls this for the focused node every frame, falling back to `mouseImpl` if this returns
    /// false.
    final bool runMouseInputActions() {

        return this.runInputActionsImpl(true);

    }

    mixin template makeHoverable() {

        import fluid.node;
        import std.format;

        static assert(is(typeof(this) : Node), format!"%s : FluidHoverable must inherit from a Node"(typeid(this)));

        override ref inout(bool) isDisabled() inout {

            return super.isDisabled;

        }

    }

    mixin template enableInputActions() {

        import std.string;
        import std.traits;
        import fluid.node;
        import fluid.input;

        static assert(is(typeof(this) : Node),
            format!"%s : FluidHoverable must inherit from Node"(typeid(this)));

        // Provide a default implementation of inputActionImpl
        static if (!is(typeof(super) : FluidHoverable))
        bool inputActionImpl(immutable InputActionID id, bool active) {

            return false;

        }

        override bool runInputActionImpl(immutable InputActionID action, bool isActive) {

            import std.meta : Filter;
            import fluid.io.action : InputActionHandlers, runInputActionHandler;

            alias This = typeof(this);

            // The programmer may override the action
            if (inputActionImpl(action, isActive)) return true;

            // Run the action
            return runInputActionHandler(this, action, isActive);

        }

    }

}

/// Check for `@WhileDown`
enum shouldActivateWhileDown(alias overload) = hasUDA!(overload, fluid.input.WhileDown);

alias runInputActionHandler = fluid.io.action.runInputActionHandler;

private bool runInputActionsImpl(FluidHoverable hoverable, bool mouse) {

    auto tree = hoverable.asNode.tree;
    bool handled;

    // Run all active actions
    if (!mouse || hoverable.isHovered)
    foreach_reverse (binding; tree.activeActions[]) {

        if (InputStroke.isMouseItem(binding.trigger) != mouse) continue;

        handled = hoverable.runInputAction(binding.action, true) || handled;

        // Stop once handled
        if (handled) break;

    }

    // Run all "while down" actions
    foreach (binding; tree.downActions[]) {

        if (InputStroke.isMouseItem(binding.trigger) != mouse) continue;

        handled = hoverable.runInputAction(binding.action, false) || handled;

    }

    return handled;

}

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

/// An interface to be implemented by all nodes that can take focus.
///
/// Note: Input nodes often have many things in common. If you want to create an input-taking node, you're likely better
/// off extending from `FluidInput`.
interface FluidFocusable : FluidHoverable {

    /// Handle input. Called each frame when focused.
    bool focusImpl();

    /// Set focus to this node.
    ///
    /// Implementation would usually assign `tree.focus` to self for this to take effect. It is legal, however, for this
    /// method to redirect the focus to another node (by calling its `focus()` method), or ignore the request.
    void focus();

    /// Check if this node has focus. Recommended implementation: `return tree.focus is this`. Proxy nodes, such as
    /// `FluidFilePicker` might choose to return the value of the node they hold.
    bool isFocused() const;

    /// Run input actions for the node.
    ///
    /// Internal. `Node` calls this for the focused node every frame, falling back to `keyboardImpl` if this returns
    /// false.
    final bool runFocusInputActions() {

        return this.runInputActionsImpl(false);

    }

}

/// An interface to be implemented by nodes that accept scroll input.
interface FluidScrollable {

    /// Returns true if the node can react to given scroll.
    ///
    /// Should return false if the given scroll has no effect, either because it scroll on an unsupported axis, or
    /// because the axis is currently maxed out.
    bool canScroll(Vector2 value) const;

    /// React to scroll wheel input.
    void scrollImpl(Vector2 value);

    /// Scroll to given child node.
    /// Params:
    ///     child     = Child to scroll to.
    ///     parentBox = Outer box of this node (the scrollable).
    ///     childBox  = Outer box of the child node (the target).
    /// Returns:
    ///     New rectangle for the childBox.
    Rectangle shallowScrollTo(const Node child, Rectangle parentBox, Rectangle childBox);

    /// Get current scroll value.
    float scroll() const;

    /// Set scroll value.
    float scroll(float value);

}

/// Represents a general input node.
abstract class InputNode(Parent : Node) : Parent, FluidFocusable, Focusable, Hoverable {

    mixin makeHoverable;
    mixin enableInputActions;

    FocusIO focusIO;
    HoverIO hoverIO;

    /// Callback to run when the input value is altered.
    void delegate() changed;

    /// Callback to run when the input is submitted.
    void delegate() submitted;

    this(T...)(T sup) {

        super(sup);

    }

    alias opEquals = typeof(super).opEquals;

    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

    /// Handle mouse input if no input action did.
    ///
    /// Usually, you'd prefer to define a method marked with an `InputAction` enum. This function is preferred for more
    /// advanced usage.
    ///
    /// Only one node can run its `mouseImpl` callback per frame, specifically, the last one to register its input.
    /// This is to prevent parents or overlapping children to take input when another node is drawn on top.
    protected override void mouseImpl() { }

    protected bool keyboardImpl() {

        return false;

    }

    override bool hoverImpl() {

        return false;

    }

    /// Handle keyboard and gamepad input if no input action did.
    ///
    /// Usually, you'd prefer to define a method marked with an `InputAction` enum. This function is preferred for more
    /// advanced usage.
    ///
    /// This will be called each frame as long as this node has focus, unless an `InputAction` was triggered first.
    ///
    /// Returns: True if the input was handled, false if not.
    override bool focusImpl() {

        return keyboardImpl();

    }

    /// Respond to an input action by its ID. 
    ///
    /// This endpoint is used by the new I/O system. `InputNode` implements this by redirecting the input
    /// to `runInputAction`.
    override bool actionImpl(InputActionID id, bool isActive) {

        return runInputAction(id, isActive);

    }

    /// Check if the node is being pressed. Performs action lookup.
    ///
    /// This is a helper for nodes that might do something when pressed, for example, buttons.
    protected bool checkIsPressed() {

        return (isHovered && tree.isMouseDown!(FluidInputAction.press))
            || (isFocused && tree.isFocusDown!(FluidInputAction.press));

    }

    override void resizeImpl(Vector2 space) {

        use(focusIO);
        use(hoverIO);

        static if (!isAbstractFunction!(typeof(super).resizeImpl)) {
            super.resizeImpl(space);
        }

    }

    /// Change the focus to this node.
    void focus() {

        import fluid.actions;

        // Ignore if disabled
        if (isDisabled) return;

        // Switch focus using the active I/O technique
        if (focusIO) {
            focusIO.currentFocus = this;
        }
        else {
            tree.focus = this;
        }

        // Ensure this node is in view
        this.scrollIntoView();

    }

    override bool isHovered() const {

        if (hoverIO) {
            return hoverIO.isHovered(this);
        }
        else {
            return super.isHovered();
        }

    }

    override protected void focusPreviousOrNext(FluidInputAction actionType) {

        super.focusPreviousOrNext(actionType);

    }

    @(FluidInputAction.focusPrevious, FluidInputAction.focusNext)
    protected bool focusPreviousOrNextBool(FluidInputAction actionType) {

        if (focusIO) return false;
        focusPreviousOrNext(actionType);
        return true;
    }

    override protected void focusInDirection(FluidInputAction actionType) {

        super.focusInDirection(actionType);

    }

    @(FluidInputAction.focusLeft, FluidInputAction.focusRight)
    @(FluidInputAction.focusUp, FluidInputAction.focusDown)
    protected bool focusInDirectionBool(FluidInputAction action) {

        if (focusIO) return false;
        focusInDirection(action);
        return true;

    }

    @property {

        /// Check if the node has focus.
        bool isFocused() const {

            if (focusIO) {
                return cast(const Node) focusIO.currentFocus == this;
            } 
            else {
                return tree.focus is this;
            }

        }

        /// Set or remove focus from this node.
        bool isFocused(bool enable) {

            if (enable) focus();
            else if (isFocused) {

                if (focusIO) {
                    focusIO.currentFocus = null;
                } 
                else {
                    tree.focus = null;
                }

            }

            return enable;

        }

    }

}

unittest {

    import fluid.label;

    // This test checks triggering and running actions bound via UDAs, including reacting to keyboard and mouse input.

    int pressCount;
    int cancelCount;

    auto io = new HeadlessBackend;
    auto root = new class InputNode!Label {

        @safe:

        mixin enableInputActions;

        this() {
            super("");
        }

        override void resizeImpl(Vector2 space) {

            minSize = Vector2(10, 10);

        }

        @(FluidInputAction.press)
        void press() {

            pressCount++;

        }

        @(FluidInputAction.cancel)
        void cancel() {

            cancelCount++;

        }

    };

    root.io = io;
    root.theme = nullTheme;
    root.focus();

    // Press the node via focus
    io.press(KeyboardKey.enter);

    root.draw();

    assert(root.tree.isFocusActive!(FluidInputAction.press));
    assert(pressCount == 1);

    io.nextFrame;

    // Holding shouldn't trigger the callback multiple times
    root.draw();

    assert(pressCount == 1);

    // Hover the node and press it with the mouse
    io.nextFrame;
    io.release(KeyboardKey.enter);
    io.mousePosition = Vector2(5, 5);
    io.press(MouseButton.left);

    root.draw();
    root.tree.focus = null;

    // This shouldn't be enough to activate the action
    assert(pressCount == 1);

    // If we now drag away from the button and release...
    io.nextFrame;
    io.mousePosition = Vector2(15, 15);
    io.release(MouseButton.left);

    root.draw();

    // ...the action shouldn't trigger
    assert(pressCount == 1);

    // But if we release the mouse on the button
    io.nextFrame;
    io.mousePosition = Vector2(5, 5);
    io.release(MouseButton.left);

    root.draw();

    assert(pressCount == 2);
    assert(cancelCount == 0);

    // Focus the node again
    root.focus();

    // Press escape to cancel
    io.nextFrame;
    io.press(KeyboardKey.escape);

    root.draw();

    assert(pressCount == 2);
    assert(cancelCount == 1);

}

unittest {

    import fluid.space;
    import fluid.button;

    // This test checks if "hover slipping" happens; namely, if the user clicks and holds on an object, then hovers on
    // something else and releases, the click should be cancelled, and no other object should react to the same click.

    class SquareButton : Button {

        mixin enableInputActions;

        this(T...)(T t) {
            super(t);
        }

        override void resizeImpl(Vector2) {
            minSize = Vector2(10, 10);
        }

    }

    int[2] pressCount;
    SquareButton[2] buttons;

    auto io = new HeadlessBackend;
    auto root = hspace(
        .nullTheme,
        buttons[0] = new SquareButton("", delegate { pressCount[0]++; }),
        buttons[1] = new SquareButton("", delegate { pressCount[1]++; }),
    );

    root.io = io;

    // Press the left button
    io.mousePosition = Vector2(5, 5);
    io.press(MouseButton.left);

    root.draw();

    // Release it
    io.release(MouseButton.left);

    root.draw();

    assert(root.tree.hover is buttons[0]);
    assert(pressCount == [1, 0], "Left button should trigger");

    // Press the right button
    io.nextFrame;
    io.mousePosition = Vector2(15, 5);
    io.press(MouseButton.left);

    root.draw();

    // Release it
    io.release(MouseButton.left);

    root.draw();

    assert(pressCount == [1, 1], "Right button should trigger");

    // Press the left button, but don't release
    io.nextFrame;
    io.mousePosition = Vector2(5, 5);
    io.press(MouseButton.left);

    root.draw();

    assert( buttons[0].isPressed);
    assert(!buttons[1].isPressed);

    // Move the cursor over the right button
    io.nextFrame;
    io.mousePosition = Vector2(15, 5);

    root.draw();

    // Left button should have tree-scope hover, but isHovered status is undefined. At the time of writing, only the
    // right button will be isHovered and neither will be isPressed.
    //
    // TODO It might be a good idea to make neither isHovered. Consider new condition:
    //
    //      (_isHovered && tree.hover is this && !_isDisabled && !tree.isBranchDisabled)
    //
    // This should also fix having two nodes visually hovered in case they overlap.
    //
    // Other frameworks might retain isPressed status on the left button, but it might good idea to keep current
    // behavior as a visual clue it wouldn't trigger.
    assert(root.tree.hover is buttons[0]);

    // Release the button on the next frame
    io.nextFrame;
    io.release(MouseButton.left);

    root.draw();

    assert(pressCount == [1, 1], "Neither button should trigger on lost hover");

    // Things should go to normal next frame
    io.nextFrame;
    io.press(MouseButton.left);

    root.draw();

    // So we can expect the right button to trigger now
    io.nextFrame;
    io.release(MouseButton.left);

    root.draw();

    assert(root.tree.hover is buttons[1]);
    assert(pressCount == [1, 2]);

}
