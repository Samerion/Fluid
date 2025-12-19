///
module fluid.input;

import std.meta;
import std.format;
import std.traits;
import std.algorithm;

import fluid.node;
import fluid.tree;
import fluid.style;

public import fluid.input_node;
import fluid.io.focus;
import fluid.io.hover;
public import fluid.io.action;

import fluid.future.context;


@safe:


/// Make a InputAction handler react to every frame as long as the action is being held (mouse button held down,
/// key held down, etc.).
enum WhileHeld;

alias WhileDown = WhileHeld;

/// This meta-UDA can be attached to an enum definition, so Fluid would recognize its members
/// as input action definitions. These members can then be attached as attributes to functions
/// to turn them into input action handlers.
///
/// You can get the ID of an input action by passing it to `inputActionID`, for example
/// `inputActionID!(FluidInputAction.press)`.
///
/// All built-in input actions are defined in `FluidInputAction`.
enum InputAction;

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
///
/// Each input action has a unique ID based on its position in the executable binary. You can get the ID
/// using `inputActionID`.
///
/// See_Also:
///     `InputAction`
immutable struct InputActionID {
    import fluid.future.static_id;

    StaticID staticID;

    alias staticID this;

    private this(StaticID staticID) immutable {
        this.staticID = staticID;
    }

    bool opEqual(InputActionID other) {
        return id == other.id;
    }
}

/// Get the ID of an input action.
/// Params:
///     action = Action to get the ID of.
/// Returns:
///     `InputActionID` struct with the action encoded.
InputActionID inputActionID(alias action)() {
    import fluid.future.static_id;
    return InputActionID(staticID!action);

}

unittest {

    enum MyEnum {
        foo = 123,
    }

    @InputAction
    enum MyAction {
        foo,
    }

    static assert(isInputAction!(FluidInputAction.entryUp));
    static assert(isInputAction!(MyAction.foo));

    static assert(!isInputAction!InputNode);
    static assert(!isInputAction!InputAction);
    static assert(!isInputAction!(inputActionID!(FluidInputAction.entryUp)));
    static assert(!isInputAction!FluidInputAction);
    static assert(!isInputAction!MyEnum);
    static assert(!isInputAction!(MyEnum.foo));
    static assert(!isInputAction!MyAction);


}

unittest {

    assert(inputActionID!(FluidInputAction.press) == inputActionID!(FluidInputAction.press));
    assert(inputActionID!(FluidInputAction.press) != inputActionID!(FluidInputAction.entryUp));

    // IDs should have the same equality as the enum members, within the same enum
    // This will not be the case for enum values with explicitly assigned values (but probably should be!)
    foreach (left; EnumMembers!FluidInputAction) {

        foreach (right; EnumMembers!FluidInputAction) {

            if (left == right)
                assert(inputActionID!left == inputActionID!right);
            else
                assert(inputActionID!left != inputActionID!right);

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

    assert(inputActionID!(FooActions.action) == inputActionID!(FooActions.action));
    assert(inputActionID!(FooActions.action) != inputActionID!(BarActions.action));
    assert(inputActionID!(FooActions.action) != inputActionID!(FluidInputAction.press));
    assert(inputActionID!(BarActions.action) != inputActionID!(FluidInputAction.press));

}

@system
unittest {

    import std.concurrency;

    // IDs are global across threads
    auto t0 = inputActionID!(FluidInputAction.press);

    spawn({

        ownerTid.send(inputActionID!(FluidInputAction.press));

        spawn({

            ownerTid.send(inputActionID!(FluidInputAction.press));

        });

        ownerTid.send(receiveOnly!InputActionID);

        ownerTid.send(inputActionID!(FluidInputAction.cancel));

    });

    auto t1 = receiveOnly!InputActionID;
    auto t2 = receiveOnly!InputActionID;

    auto c0 = inputActionID!(FluidInputAction.cancel);
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

    return tree.downActions[].canFind!"a.action == b"(inputActionID!type);

}

version (TODO)
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

version (TODO)
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
        => a.action == inputActionID!type
        && !InputStroke.isMouseItem(a.trigger));

}

version (TODO)
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

/// Check for `@WhileDown`
enum shouldActivateWhileDown(alias overload) = hasUDA!(overload, fluid.input.WhileDown);

alias runInputActionHandler = fluid.io.action.runInputActionHandler;

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
