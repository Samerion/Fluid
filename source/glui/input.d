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

/// Reference to a specific gamepad's button for `InputStroke`.
struct NthGamepadButton {

    int gamepadNumber;
    GluiGamepadButton button;

}

/// Reference to a specific gamepad's axis for `InputStroke`.
///
/// Support to be implemented.
///
/// TODO this makes no sense, better to have the backend supply axes as buttons.
struct NthGamepadAxis {

    int gamepadNumber;
    GluiGamepadAxis axis;

}

/// Represents a key or button input combination.
struct InputStroke {

    import std.sumtype;

    alias Item = SumType!(GluiKeyboardKey, GluiMouseButton, NthGamepadButton/*, NthGamepadAxis*/);

    Item[] input;
    invariant(input.length >= 1);

    this(T...)(T items)
    if (!is(items : Item[])) {

        input.length = items.length;
        static foreach (i, item; items) {

            // Make gamepad buttons default to gamepad 0
            static if (is(typeof(item) : GluiGamepadButton)) {

                input[i] = Item(NthGamepadButton(0, item));

            }

            // Put all remaining stuff directly
            else input[i] = Item(item);

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

    /// Check if all keys or buttons required for the stroke are held down. This is is to make sure only one action is
    /// performed for each stroke.
    bool isDown(const GluiBackend backend) const @trusted {

        return input.all!(a => isDown(backend, a));

    }

    /// Check if the stroke has been triggered during this frame.
    ///
    /// If the last item of the action is a mouse button, the action will be triggered on release. If it's a keyboard
    /// key or gamepad button, it'll be triggered on press.
    bool isActive(const GluiBackend backend) const @trusted {

        return (

            // For all but the last item, check if it's held down
            input[0 .. $-1].all!(a => isDown(backend, a))

            // For the last item, check if it's pressed or released, depending on the type
            && input[$-1].match!(
                (GluiKeyboardKey key) => backend.isPressed(key) || backend.isRepeated(key),
                (GluiMouseButton button) => backend.isReleased(button),
                (NthGamepadButton button) => backend.isPressed(button.tupleof),  // TODO gamepad repeat
                // (NthGamepadAxis axis) => GetGamepadAxisMovement() ...
            )

        );

    }

    private static bool isDown(const GluiBackend backend, Item item) @trusted {

        return item.match!(

            // Keyboard
            (GluiKeyboardKey key) => backend.isDown(key),

            // A released mouse button also counts as down for our purposes, as it might trigger the action
            (GluiMouseButton button) => backend.isDown(button) || backend.isReleased(button),

            // Gamepad
            (NthGamepadButton button) => backend.isDown(button.tupleof),
            // (NthGamepadAxis axis) => GetGamepadAxisMovement() ...
        );

    }

    string toString() const {

        return format!"InputStroke(%(%s + %))"(input);

    }

}

/// This meta-UDA can be attached to an enum, so Glui would recognize members of said enum as an UDA defining input
/// actions.
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
    /// would merge these two declarations, so we're using `&_id` for safety. Example of such behavior can be achieved
    /// using `ld.gold` with `--icf=all`. It's possible the linker could be aware we're checking the function address
    // (`--icf=safe` works correctly), but again, we prefer to play it safe. Alternatively, we could test for this
    /// behavior when the program starts, but it probably isn't worth it.
    align(1)
    private static immutable bool _id;

    static InputActionID id() {

        return InputActionID(typeof(this)());

    }

}

inout(InputStroke)[] getStrokes(alias type)(inout(LayoutTree)* tree)
if (isInputActionType!type) {

    // Note: `get` doesn't support `inout`
    if (auto r = InputAction!type in tree.boundInputs) return *r;
    else return null;

}

/// Get all strokes that might be performed with a mouse that may trigger this action.
auto getMouseStrokes(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return getStrokes!type(tree).filter!"a.isMouseStroke";

}

/// Get all strokes that might be performed with a keyboard or gamepad that may trigger this action.
auto getFocusStrokes(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return getStrokes!type(tree).filter!"!a.isMouseStroke";

}

/// Check if any stroke bound to this action is being held.
bool isDown(alias type)(const(LayoutTree)* tree)
if (isInputActionType!type) {

    return getStrokes!type(tree).any!(a => a.isDown(tree.backend));
    // Maybe this could be faster? Cache the result? Something? No idea.

}

/// Check if a mouse stroke bound to this action is being held.
bool isMouseDown(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return getMouseStrokes!type(tree).any!(a => a.isDown(tree.backend));

}

/// Check if a keyboard or gamepad stroke bound to this action is being held.
bool isFocusDown(alias type)(LayoutTree* tree)
if (isInputActionType!type) {

    return getFocusStrokes!type(tree).any!(a => a.isDown(tree.backend));

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


unittest {

    assert(InputAction!(GluiInputAction.press).id == InputAction!(GluiInputAction.press).id);
    assert(InputAction!(GluiInputAction.press).id != InputAction!(GluiInputAction.entryUp).id);

}

/// An interface to be implemented by all nodes that can perform actions when hovered (eg. on click)
interface GluiHoverable {

    /// Handle mouse input on the node.
    void mouseImpl();

    /// Check if the node is disabled. `mixin makeHoverable` to implement.
    ref inout(bool) isDisabled() inout;

    /// Get the underlying node. `mixin makeHoverable` to implement.
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

    /// Take input when focused.
    bool focusImpl();

    /// Set focus to this node.
    ///
    /// Implementation would usually assign `tree.focus` to self for this to take effect. It is legal, however, for this
    /// method to redirect the focus at another node (by calling its `focus()` method), or ignore the request.
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

    override const(Style) pickStyle() const {

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
