///
module glui.input;

import raylib;

import std.meta;
import std.format;
import std.traits;

import glui.node;
import glui.style;


@safe:


/// Default input actions one can listen to.
@InputAction
enum GluiInputAction {

    // Basic
    press,   /// Press the input. Used for example to activate buttons.
    submit,  /// Submit input, eg. finish writing in textInput.
    cancel,  /// Cancel,

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

enum InputActionStatus {

    released,
    pressed,
    up,
    down,

}

/// ID of an input action.
immutable struct InputActionID {

    /// Unique ID of the action.
    size_t id;

    /// Action name. Only emitted when debugging.
    debug string name;

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
    static assert(!isInputActionType!GluiInputAction);
    static assert(!isInputActionType!MyEnum);
    static assert(!isInputActionType!(MyEnum.foo));
    static assert(!isInputActionType!MyAction);


}

/// This UDA can be attached to a GluiInput `bool` returning method to make it listen for actions.
///
/// Action types are resolved at compile-time using symbols, so you can supply any `@InputAction`-marked enum defining
/// input actions. All built-in enums are defined in `GluiInputAction`.
///
/// If the method returns `true`, it is understood that the action has been processed and no more actions will be
/// emitted during the frame. If it returns `false`, other actions and keyboardImpl will be tried until any call returns
/// `true` or no handlers are left.
struct InputAction(alias actionType)
if (isInputActionType!actionType) {

    import std.traits;

    alias type = actionType;
    auto status = InputActionStatus.released;

    alias id this;

    private static immutable bool _id;

    static InputActionID id() {

        debug return InputActionID(cast(size_t) &_id, fullyQualifiedName!(typeof(this)));
        else  return InputActionID(cast(size_t) &_id);
        // Note: we could be directly getting the address of the function itself (&id), but it's possible some linkers
        // would merge these two declarations, so we're using &_id for safety.
        // Example of such behavior can be achieved using ld.gold with --icf=all.
        // It's possible the linker could be aware of taking the address (--icf=safe works correctly), but again, we
        // prefer to play it safe.
        // Alternatively, we could test for this behavior when the program starts, but it probably isn't worth it.

    }

}

/// An interface to be implemented by all nodes that can perform actions when hovered (eg. on click)
interface GluiHoverable {

    /// Handle mouse input on the node.
    void mouseImpl();

    /// Check if the node is disabled. `mixin MakeHoverable` to implement.
    ref inout(bool) isDisabled() inout;

    /// Get the underlying node. `mixin MakeHoverable` to implement.
    inout(GluiNode) asNode() inout;

    mixin template makeHoverable() {

        import glui.node;
        import std.format;

        static assert(is(typeof(this) : GluiNode), format!"%s : GluiHoverable must inherit from a Node"(typeid(this)));

        override ref inout(bool) isDisabled() inout {

            return super.isDisabled;

        }

        /// Get the underlying node.
        inout(GluiNode) asNode() inout {

            return this;

        }

    }

}

/// An interface to be implemented by all nodes that can take focus.
///
/// Note: Input nodes often have many things in common. If you want to create an input-taking node, you're likely better
/// off extending from `GluiInput`.
interface GluiFocusable : GluiHoverable {

    /// Take keyboard input.
    bool keyboardImpl();

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
    /// Implement by adding `mixin runInputActions` in your class.
    void runInputActions();

    /// Mixin template to enable input actions in this class.
    mixin template enableInputActions() {

        // Implement the interface method
        override void runInputActions() {

            import glui.input;
            import std.string, std.traits;

            // Check if this class has implemented this method
            assert(typeid(this) is typeid(typeof(this)), format!"%s is missing `mixin runInputActions;`"(typeid(this)));

            // Find members with the InputAction UDA
            static foreach (member; getSymbolsByUDA!(typeof(this), InputAction)) {

                // Find all bound actions
                static foreach (uda; getUDAs!(member, InputAction)) {

                    static assert(false, "TODO");

                }

            }

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
    /// Only one node can run its `inputImpl` callback per frame, specifically, the last one to register its input.
    /// This is to prevent parents or overlapping children to take input when another node is drawn on them.
    protected abstract void mouseImpl();

    /// Handle keyboard input.
    ///
    /// This will be called each frame as long as this node has focus.
    ///
    /// Returns: True if the input was handled, false if not.
    protected abstract bool keyboardImpl();

    /// Change the focus to this node.
    void focus() {

        // Ignore if disabled
        if (isDisabled) return;

        tree.focus = this;

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
