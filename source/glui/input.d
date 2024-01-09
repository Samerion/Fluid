///
module glui.input;

import std.meta;
import std.format;
import std.traits;
import std.algorithm;

import glui.node;
import glui.tree;
import glui.style;
import glui.backend;


@safe:


/// Make a GluiInputAction handler react to every frame as long as the action is being held (mouse button held down,
/// key held down, etc.).
enum whileDown;

/// Default input actions one can listen to.
@InputAction
enum GluiInputAction {

    // Basic
    press,   /// Press the input. Used for example to activate buttons.
    submit,  /// Submit input, eg. finish writing in textInput.
    cancel,  /// Cancel the input.

    // Focus
    focusPrevious,  /// Focus previous input.
    focusNext,      /// Focus next input.
    focusLeft,      /// Focus input on the left.
    focusRight,     /// Focus input on the right.
    focusUp,        /// Focus input above.
    focusDown,      /// Focus input below.

    // Input
    backspace,      /// Erase last character in an input.
    backspaceWord,  /// Erase last a word in an input.
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
        debug this.name = fullyQualifiedName!actionType;

    }

    bool opEqual(InputActionID other) {

        return id == other.id;

    }

}

/// Check if the given symbol is an input action type.
///
/// The symbol symbol must be a member of an enum marked with `@InputAction`. The enum $(B must not) be a manifest
/// constant (eg. `enum foo = 123;`).
template isInputActionType(alias actionType) {

    // Require the action type to be an enum
    static if (is(typeof(actionType) == enum)) {

        // Search through the enum attributes
        static foreach (attribute; __traits(getAttributes, typeof(actionType))) {

            // Not yet found
            static if (!is(typeof(isInputActionType) == bool)) {

                // Check if this is the attribute we're looking for
                static if (__traits(isSame, attribute, InputAction)) {

                    enum isInputActionType = true;

                }

            }

        }

    }

    // Not found
    static if (!is(typeof(isInputActionType) == bool)) {

        // Respond as false
        enum isInputActionType = false;

    }

}

unittest {

    enum MyEnum {
        foo = 123,
    }

    @InputAction
    enum MyAction {
        foo,
    }

    static assert(isInputActionType!(GluiInputAction.entryUp));
    static assert(isInputActionType!(MyAction.foo));

    static assert(!isInputActionType!GluiInput);
    static assert(!isInputActionType!(InputAction!(GluiInputAction.entryUp)));
    static assert(!isInputActionType!GluiInputAction);
    static assert(!isInputActionType!MyEnum);
    static assert(!isInputActionType!(MyEnum.foo));
    static assert(!isInputActionType!MyAction);


}

/// Represents a key or button input combination.
struct InputStroke {

    import std.sumtype;

    alias Item = SumType!(GluiKeyboardKey, GluiMouseButton, GluiGamepadButton);

    Item[] input;
    invariant(input.length >= 1);

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

    /// Check if the last item of this input stroke is done with a mouse
    bool isMouseStroke() const {

        return input[$-1].match!(
            (GluiMouseButton _) => true,
            (_) => false,
        );

    }

    unittest {

        assert(!InputStroke(GluiKeyboardKey.leftControl).isMouseStroke);
        assert(!InputStroke(GluiKeyboardKey.w).isMouseStroke);
        assert(!InputStroke(GluiKeyboardKey.leftControl, GluiKeyboardKey.w).isMouseStroke);

        assert(InputStroke(GluiMouseButton.left).isMouseStroke);
        assert(InputStroke(GluiKeyboardKey.leftControl, GluiMouseButton.left).isMouseStroke);

        assert(!InputStroke(GluiGamepadButton.triangle).isMouseStroke);
        assert(!InputStroke(GluiKeyboardKey.leftControl, GluiGamepadButton.triangle).isMouseStroke);

    }

    /// Check if all keys or buttons required for the stroke are held down.
    bool isDown(const GluiBackend backend) const @trusted {

        return input.all!(a => isDown(backend, a));

    }

    ///
    unittest {

        auto stroke = InputStroke(GluiKeyboardKey.leftControl, GluiKeyboardKey.w);
        auto io = new HeadlessBackend;

        // No keys pressed
        assert(!stroke.isDown(io));

        // Control pressed
        io.press(GluiKeyboardKey.leftControl);
        assert(!stroke.isDown(io));

        // Both keys pressed
        io.press(GluiKeyboardKey.w);
        assert(stroke.isDown(io));

        // Still pressed, but not immediately
        io.nextFrame;
        assert(stroke.isDown(io));

        // W pressed
        io.release(GluiKeyboardKey.leftControl);
        assert(!stroke.isDown(io));

    }

    /// Check if the stroke has been triggered during this frame.
    ///
    /// If the last item of the action is a mouse button, the action will be triggered on release. If it's a keyboard
    /// key or gamepad button, it'll be triggered on press. All previous items, if present, have to be held down at the
    /// time.
    bool isActive(const GluiBackend backend) const @trusted {

        return (

            // For all but the last item, check if it's held down
            input[0 .. $-1].all!(a => isDown(backend, a))

            // For the last item, check if it's pressed or released, depending on the type
            && input[$-1].match!(
                (GluiKeyboardKey key) => backend.isPressed(key) || backend.isRepeated(key),
                (GluiMouseButton button) => backend.isReleased(button),
                (GluiGamepadButton button) => backend.isPressed(button) || backend.isRepeated(button),
            )

        );

    }

    unittest {

        auto singleKey = InputStroke(GluiKeyboardKey.w);
        auto stroke = InputStroke(GluiKeyboardKey.leftControl, GluiKeyboardKey.leftShift, GluiKeyboardKey.w);
        auto io = new HeadlessBackend;

        // No key pressed
        assert(!singleKey.isActive(io));
        assert(!stroke.isActive(io));

        io.press(GluiKeyboardKey.w);

        // Just pressed the "W" key
        assert(singleKey.isActive(io));
        assert(!stroke.isActive(io));

        io.nextFrame;

        // The stroke stops being active on the next frame
        assert(!singleKey.isActive(io));
        assert(!stroke.isActive(io));

        io.press(GluiKeyboardKey.leftControl);
        io.press(GluiKeyboardKey.leftShift);

        assert(!singleKey.isActive(io));
        assert(!stroke.isActive(io));

        // The last key needs to be pressed during the current frame
        io.press(GluiKeyboardKey.w);

        assert(singleKey.isActive(io));
        assert(stroke.isActive(io));

        io.release(GluiKeyboardKey.w);

        assert(!singleKey.isActive(io));
        assert(!stroke.isActive(io));

    }

    /// Mouse actions are activated on release
    unittest {

        auto stroke = InputStroke(GluiKeyboardKey.leftControl, GluiMouseButton.left);
        auto io = new HeadlessBackend;

        assert(!stroke.isActive(io));

        io.press(GluiKeyboardKey.leftControl);
        io.press(GluiMouseButton.left);

        assert(!stroke.isActive(io));

        io.release(GluiMouseButton.left);

        assert(stroke.isActive(io));

        // The action won't trigger if previous keys aren't held down
        io.release(GluiKeyboardKey.leftControl);

        assert(!stroke.isActive(io));

    }

    private static bool isDown(const GluiBackend backend, Item item) @trusted {

        return item.match!(

            // Keyboard
            (GluiKeyboardKey key) => backend.isDown(key),

            // A released mouse button also counts as down for our purposes, as it might trigger the action
            (GluiMouseButton button) => backend.isDown(button) || backend.isReleased(button),

            // Gamepad
            (GluiGamepadButton button) => backend.isDown(button) != 0
        );

    }

    string toString() const {

        return format!"InputStroke(%(%s + %))"(input);

    }

}

/// This meta-UDA can be attached to an enum, so Glui would recognize members of said enum as an UDA defining input
/// actions. As an UDA, this template should be used without instantiating.
///
/// This template also serves to provide unique identifiers for each action type, generated on startup. For example,
/// `InputAction!(GluiInputAction.press).id` will have the same value anywhere in the program.
///
/// Action types are resolved at compile-time using symbols, so you can supply any `@InputAction`-marked enum defining
/// input actions. All built-in enums are defined in `GluiInputAction`.
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

    assert(InputAction!(GluiInputAction.press).id == InputAction!(GluiInputAction.press).id);
    assert(InputAction!(GluiInputAction.press).id != InputAction!(GluiInputAction.entryUp).id);

    // IDs should have the same equality as the enum members, within the same enum
    // This will not be the case for enum values with explicitly assigned values (but probably should be!)
    foreach (left; EnumMembers!GluiInputAction) {

        foreach (right; EnumMembers!GluiInputAction) {

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
    assert(InputAction!(FooActions.action).id != InputAction!(GluiInputAction.press).id);
    assert(InputAction!(BarActions.action).id != InputAction!(GluiInputAction.press).id);

}

@system
unittest {

    import std.concurrency;

    // IDs are global across threads
    auto t0 = InputAction!(GluiInputAction.press).id;

    spawn({

        ownerTid.send(InputAction!(GluiInputAction.press).id);

        spawn({

            ownerTid.send(InputAction!(GluiInputAction.press).id);

        });

        ownerTid.send(receiveOnly!InputActionID);

        ownerTid.send(InputAction!(GluiInputAction.cancel).id);

    });

    auto t1 = receiveOnly!InputActionID;
    auto t2 = receiveOnly!InputActionID;

    auto c0 = InputAction!(GluiInputAction.cancel).id;
    auto c1 = receiveOnly!InputActionID;

    assert(t0 == t1);
    assert(t1 == t2);

    assert(c0 != t0);
    assert(c1 != t1);
    assert(c0 != t1);
    assert(c1 != t0);

    assert(t0 == t1);

}

inout(InputStroke)[] getStrokes(alias type)(inout(LayoutTree)* tree)
if (isInputActionType!type) {

    // Note: `get` doesn't support `inout`
    if (auto r = InputAction!type in tree.boundInputs) return *r;
    else return null;

}

unittest {

    import glui.space;

    auto tree = new LayoutTree(vspace());
    auto strokes = tree.getStrokes!(GluiInputAction.press);

    // "press" can be activated with the left mouse button
    assert(strokes.canFind(InputStroke(GluiMouseButton.left)));

    // It can also be activated with the enter key
    assert(strokes.canFind(InputStroke(GluiKeyboardKey.enter)));

}

/// Get all strokes that might be performed with a mouse that may trigger this action.
auto getMouseStrokes(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return getStrokes!type(tree).filter!"a.isMouseStroke";

}

unittest {

    import glui.space;

    auto tree = new LayoutTree(vspace());
    auto strokes = tree.getMouseStrokes!(GluiInputAction.press);

    // Out of all mouse buttons, "press" can only be activated with the left button, at least with the default bindings
    assert(strokes.equal([InputStroke(GluiMouseButton.left)]));

}

/// Get all strokes that might be performed with a keyboard or gamepad that may trigger this action.
auto getFocusStrokes(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return getStrokes!type(tree).filter!"!a.isMouseStroke";

}

unittest {

    import glui.space;

    auto tree = new LayoutTree(vspace());
    auto strokes = tree.getFocusStrokes!(GluiInputAction.press);

    // "press" can be activated with the enter key
    assert(strokes.canFind(InputStroke(GluiKeyboardKey.enter)));

    // Because mouse strokes are filtered out, they will not appear in the result
    assert(!strokes.canFind(InputStroke(GluiMouseButton.left)));

}

/// Check if any stroke bound to this action is being held.
bool isDown(alias type)(const(LayoutTree)* tree)
if (isInputActionType!type) {

    return getStrokes!type(tree).any!(a => a.isDown(tree.backend));
    // Maybe this could be faster? Cache the result? Something? No idea.

}

unittest {

    import glui.space;

    auto tree = new LayoutTree(vspace());
    auto io = new HeadlessBackend;

    tree.io = io;

    // Nothing pressed, action not activated
    assert(!tree.isDown!(GluiInputAction.backspaceWord));

    io.press(GluiKeyboardKey.leftControl);
    io.press(GluiKeyboardKey.backspace);

    // The action is now held down with the ctrl+blackspace stroke
    assert(tree.isDown!(GluiInputAction.backspaceWord));

    io.release(GluiKeyboardKey.backspace);
    io.press(GluiKeyboardKey.w);

    // ctrl+W also activates the stroke
    assert(tree.isDown!(GluiInputAction.backspaceWord));

    io.release(GluiKeyboardKey.leftControl);

    // Control up, won't match any stroke now
    assert(!tree.isDown!(GluiInputAction.backspaceWord));

}

/// Check if a mouse stroke bound to this action is being held.
bool isMouseDown(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return getMouseStrokes!type(tree).any!(a => a.isDown(tree.backend));

}

unittest {

    import glui.space;

    auto tree = new LayoutTree(vspace());
    auto io = new HeadlessBackend;

    tree.io = io;

    assert(!tree.isDown!(GluiInputAction.press));

    io.press(GluiMouseButton.left);

    // Pressing with a mouse
    assert(tree.isDown!(GluiInputAction.press));
    assert(tree.isMouseDown!(GluiInputAction.press));

    io.release(GluiMouseButton.left);

    // Releasing a mouse key still counts as holding it down
    // This is important — a released mouse is used to trigger the action
    assert(tree.isDown!(GluiInputAction.press));
    assert(tree.isMouseDown!(GluiInputAction.press));

    // Need to wait a frame
    io.nextFrame;

    assert(!tree.isDown!(GluiInputAction.press));

    io.press(GluiKeyboardKey.enter);

    // Pressing with a keyboard
    assert(tree.isDown!(GluiInputAction.press));
    assert(!tree.isMouseDown!(GluiInputAction.press));

    io.release(GluiKeyboardKey.enter);

    assert(!tree.isDown!(GluiInputAction.press));

}

/// Check if a keyboard or gamepad stroke bound to this action is being held.
bool isFocusDown(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return getFocusStrokes!type(tree).any!(a => a.isDown(tree.backend));

}

unittest {

    import glui.space;

    auto tree = new LayoutTree(vspace());
    auto io = new HeadlessBackend;

    tree.io = io;

    assert(!tree.isDown!(GluiInputAction.press));

    io.press(GluiKeyboardKey.enter);

    // Pressing with a keyboard
    assert(tree.isDown!(GluiInputAction.press));
    assert(tree.isFocusDown!(GluiInputAction.press));

    io.release(GluiKeyboardKey.enter);
    io.press(GluiMouseButton.left);

    // Pressing with a mouse
    assert(tree.isDown!(GluiInputAction.press));
    assert(!tree.isFocusDown!(GluiInputAction.press));

}

/// Check if any stroke bound to this action is active.
bool isActive(alias type)(const(LayoutTree)* tree)
if (isInputActionType!type) {

    return getStrokes!type(tree).any!"a.isActive";

}

/// Check if a mouse stroke bound to this action is active
bool isMouseActive(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return getMouseStrokes!type(tree).any!(a => a.isActive(tree.backend));

}

/// Check if a keyboard or gamepad stroke bound to this action is active.
bool isFocusActive(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return getFocusStrokes!type(tree).any!(a => a.isActive(tree.backend));

}

/// An interface to be implemented by all nodes that can perform actions when hovered (eg. on click)
interface GluiHoverable {

    /// Handle mouse input on the node.
    void mouseImpl();

    /// Check if the node is disabled. `mixin makeHoverable` to implement.
    ref inout(bool) isDisabled() inout;

    /// Get the underlying node.
    final inout(GluiNode) asNode() inout {

        return cast(inout GluiNode) this;

    }

    /// Run input actions for the node.
    ///
    /// Internal. `GluiNode` calls this for the focused node every frame, falling back to `mouseImpl` if this returns
    /// false.
    ///
    /// Implement by adding `mixin enableInputActions` in your class.
    bool runMouseInputActions();

    mixin template makeHoverable() {

        import glui.node;
        import std.format;

        static assert(is(typeof(this) : GluiNode), format!"%s : GluiHoverable must inherit from a Node"(typeid(this)));

        override ref inout(bool) isDisabled() inout {

            return super.isDisabled;

        }

    }

    mixin template enableInputActions() {

        import glui.node;

        static assert(is(typeof(this) : GluiNode),
            format!"%s : GluiHoverable must inherit from GluiNode"(typeid(this)));

        override bool runMouseInputActions() {

            return runInputActionsImpl!(true, typeof(this));

        }

        /// Please use enableInputActions instead of this.
        private bool runInputActionsImpl(bool mouse, This)() {

            import std.string, std.traits, std.algorithm;

            // Check if this class has implemented this method
            assert(typeid(this) is typeid(This),
                format!"%s is missing `mixin enableInputActions;`"(typeid(this)));

            // Check each member
            static foreach (memberName; __traits(allMembers, This)) {

                static foreach (overload; __traits(getOverloads, This, memberName)) {{

                    alias member = __traits(getMember, This, memberName);

                    // Filter out to functions only, also ignore deprecated functions
                    enum isMethod = !__traits(isDeprecated, member)
                        && __traits(compiles, isFunction!member)
                        && isFunction!member;
                    // TODO maybe somehow issue an error if an input action is marked deprecated?

                    static if (isMethod) {

                        // Make sure no method is marked `@InputAction`, that's invalid usage
                        alias inputActionUDAs = getUDAs!(overload, InputAction);

                        // Check for `@whileDown`
                        enum activateWhileDown = hasUDA!(overload, whileDown);

                        static assert(inputActionUDAs.length == 0,
                            format!"Please use @(%s) instead of @InputAction!(%1$s)"(inputActionUDAs[0].type));

                        // Find all bound actions
                        static foreach (actionType; __traits(getAttributes, overload)) {

                            static if (isInputActionType!actionType) {{

                                // Get any of held down strokes
                                auto strokes = tree.getStrokes!actionType

                                    // Filter to mouse or keyboard strokes
                                    .filter!(a => a.isMouseStroke == mouse)

                                    // Check if they're held down
                                    .find!(a => a.isDown(tree.backend));

                                // TODO prevent triggering an action if it could be associated with a more complex
                                //      action: for example, `C` shouldn't trigger actions if `ctrl+C` is bound and
                                //      pressed.

                                // Check if the stroke is being held down
                                if (!strokes.empty) {

                                    const condition = activateWhileDown
                                        ? strokes.front.isDown(tree.backend)
                                        : strokes.front.isActive(tree.backend);

                                    // Run the action if the stroke was performed
                                    if (condition) {

                                        // Pass the action type if applicable
                                        static if (__traits(compiles, overload(actionType))) {

                                            overload(actionType);

                                        }

                                        // Run empty
                                        else overload();

                                    }

                                    // Mark as handled
                                    return true;

                                }

                            }}

                        }

                    }

                }}

            }

            return false;

        }

    }

}

/// An interface to be implemented by all nodes that can take focus.
///
/// Note: Input nodes often have many things in common. If you want to create an input-taking node, you're likely better
/// off extending from `GluiInput`.
interface GluiFocusable : GluiHoverable {

    /// Handle input. Called each frame when focused.
    bool focusImpl();

    /// Set focus to this node.
    ///
    /// Implementation would usually assign `tree.focus` to self for this to take effect. It is legal, however, for this
    /// method to redirect the focus to another node (by calling its `focus()` method), or ignore the request.
    void focus();

    /// Check if this node has focus. Recommended implementation: `return tree.focus is this`. Proxy nodes, such as
    /// `GluiFilePicker` might choose to return the value of the node they hold.
    bool isFocused() const;

    /// Run input actions for the node.
    ///
    /// Internal. `GluiNode` calls this for the focused node every frame, falling back to `keyboardImpl` if this returns
    /// false.
    ///
    /// Implement by adding `mixin enableInputActions` in your class.
    bool runFocusInputActions();

    /// Mixin template to enable input actions in this class.
    mixin template enableInputActions() {

        private import glui.input;

        mixin GluiHoverable.enableInputActions;

        // Implement the interface method
        override bool runFocusInputActions() {

            return runInputActionsImpl!(false, typeof(this));

        }

    }

}

/// Represents a general input node.
///
/// Styles: $(UL
///     $(LI `styleKey` = Default style for the input.)
///     $(LI `focusStyleKey` = Style for when the input is focused.)
///     $(LI `disabledStyleKey` = Style for when the input is disabled.)
/// )
abstract class GluiInput(Parent : GluiNode) : Parent, GluiFocusable {

    mixin defineStyles!(
        "focusStyle", q{ style },
        "hoverStyle", q{ style },
        "disabledStyle", q{ style },
    );
    mixin makeHoverable;
    mixin enableInputActions;

    /// Callback to run when the input value is altered.
    void delegate() changed;

    /// Callback to run when the input is submitted.
    void delegate() submitted;

    this(T...)(T sup) {

        super(sup);

    }

    override inout(Style) pickStyle() inout {

        // Disabled
        if (isDisabledInherited) return disabledStyle;

        // Focused
        else if (isFocused) return focusStyle;

        // Hovered
        else if (isHovered) return hoverStyle;

        // Other
        else return style;

    }

    /// Handle mouse input.
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

    /// Handle keyboard and gamepad input.
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

    /// Check if the node is being pressed. Performs action lookup.
    ///
    /// This is a helper for nodes that might do something when pressed, for example, buttons.
    ///
    /// Preferrably, the node should implement an `isPressed` property and cache the result of this!
    protected bool checkIsPressed() {

        return (isHovered && tree.isMouseDown!(GluiInputAction.press))
            || (isFocused && tree.isFocusDown!(GluiInputAction.press));

    }

    /// Change the focus to this node.
    void focus() {

        import glui.actions;

        // Ignore if disabled
        if (isDisabled) return;

        // Switch the scroll
        tree.focus = this;

        // Ensure this node gets focus
        this.scrollIntoView();

    }

    @property {

        /// Check if the node has focus.
        bool isFocused() const {

            return tree.focus is this;

        }

        /// Set or remove focus from this node.
        bool isFocused(bool enable) {

            if (enable) focus();
            else if (isFocused) tree.focus = null;

            return enable;

        }

    }

}

unittest {

    import glui.label;

    // This test checks triggering and running actions bound via UDAs, including reacting to keyboard and mouse input.

    int pressCount;
    int cancelCount;

    auto io = new HeadlessBackend;
    auto root = new class GluiInput!GluiLabel {

        @safe:

        mixin enableInputActions;

        this() {
            super(NodeParams(), "");
        }

        override void resizeImpl(Vector2 space) {

            minSize = Vector2(10, 10);

        }

        @(GluiInputAction.press)
        void _pressed() {

            pressCount++;

        }

        @(GluiInputAction.cancel)
        void _cancelled() {

            cancelCount++;

        }

    };

    root.io = io;
    root.theme = nullTheme;
    root.focus();

    // Press the node via focus
    io.press(GluiKeyboardKey.enter);

    assert(root.tree.isFocusActive!(GluiInputAction.press));

    root.draw();

    assert(pressCount == 1);

    io.nextFrame;

    // Holding shouldn't trigger the callback multiple times
    root.draw();

    assert(pressCount == 1);

    // Hover the node and press it with the mouse
    io.nextFrame;
    io.release(GluiKeyboardKey.enter);
    io.mousePosition = Vector2(5, 5);
    io.press(GluiMouseButton.left);

    root.draw();
    root.tree.focus = null;

    // This shouldn't be enough to activate the action
    assert(pressCount == 1);

    // If we now drag away from the button and release...
    io.nextFrame;
    io.mousePosition = Vector2(15, 15);
    io.release(GluiMouseButton.left);

    root.draw();

    // ...the action shouldn't trigger
    assert(pressCount == 1);

    // But if we release the mouse on the button
    io.nextFrame;
    io.mousePosition = Vector2(5, 5);
    io.release(GluiMouseButton.left);

    root.draw();

    assert(pressCount == 2);
    assert(cancelCount == 0);

    // Focus the node again
    root.focus();

    // Press escape to cancel
    io.nextFrame;
    io.press(GluiKeyboardKey.escape);

    root.draw();

    assert(pressCount == 2);
    assert(cancelCount == 1);

}

unittest {

    import glui.space;
    import glui.button;

    // This test checks if "hover slipping" happens; namely, if the user clicks and holds on an object, then hovers on
    // something else and releases, the click should be cancelled, and no other object should react to the same click.

    class SquareButton : GluiButton!() {

        mixin enableInputActions;

        this(T...)(T t) {
            super(NodeParams(), t);
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
    io.press(GluiMouseButton.left);

    root.draw();

    // Release it
    io.release(GluiMouseButton.left);

    root.draw();

    assert(root.tree.hover is buttons[0]);
    assert(pressCount == [1, 0], "Left button should trigger");

    // Press the right button
    io.nextFrame;
    io.mousePosition = Vector2(15, 5);
    io.press(GluiMouseButton.left);

    root.draw();

    // Release it
    io.release(GluiMouseButton.left);

    root.draw();

    assert(pressCount == [1, 1], "Right button should trigger");

    // Press the left button, but don't release
    io.nextFrame;
    io.mousePosition = Vector2(5, 5);
    io.press(GluiMouseButton.left);

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
    io.release(GluiMouseButton.left);

    root.draw();

    assert(pressCount == [1, 1], "Neither button should trigger on lost hover");

    // Things should go to normal next frame
    io.nextFrame;
    io.press(GluiMouseButton.left);

    root.draw();

    // So we can expect the right button to trigger now
    io.nextFrame;
    io.release(GluiMouseButton.left);

    root.draw();

    assert(root.tree.hover is buttons[1]);
    assert(pressCount == [1, 2]);

}
