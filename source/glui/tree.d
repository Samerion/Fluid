module glui.tree;

import raylib;

import std.conv;
import std.math;

import glui.node;
import glui.input;
import glui.style;


@safe:


///
struct FocusDirection {

    struct WithPriority {

        /// Pick priority based on tree distance from the focused node.
        int priority;

        /// Square of the distance between this node and the focused node.
        float distance2;

        /// The node.
        GluiFocusable node;

        alias node this;

    }

    /// Available space box of the focused item after last frame.
    Rectangle lastFocusBox;

    /// Nodes that may get focus with tab navigation.
    GluiFocusable previous, next;

    /// First and last focusable nodes in the tree.
    GluiFocusable first, last;

    /// Focusable nodes, by direction from the focused node.
    WithPriority[4] positional;

    /// Focus priority for the node.
    ///
    /// Increased until the focused node is found, decremented afterwards. As a result, values will be the highest for
    /// nodes near the focused one.
    int priority;

    private {

        /// Value `prioerity` is summed with on each step. `1` before finding the focused node, `-1` after.
        int priorityDirection = 1;

        /// Current tree depth.
        uint depth;

    }

    /// Update focus info with the given node. Automatically called when a node is drawn, shouldn't be called manually.
    ///
    /// `previous` will be the last focusable node encountered before the focused node, and `next` will be the first one
    /// after. `first` and `last will be the last focusable nodes in the entire tree.
    ///
    /// Params:
    ///     current = Node to update the focus info with.
    ///     box     = Available space box of the node. This is the argument passed to the child in `draw(Rectangle)`
    ///     depth   = Current tree depth. Pass in `tree.depth`.
    void update(GluiNode current, Rectangle box, uint depth)
    in (current !is null, "Current node must not be null")
    do {

        import std.algorithm : either;

        auto currentFocusable = cast(GluiFocusable) current;

        // Count focus priority
        {

            // Get depth difference since last time
            const int depthDiff = depth - this.depth;

            // Count leaf steps
            priority += priorityDirection * abs(depthDiff);

            // Update depth
            this.depth = depth;

        }

        // Stop if the current node can't take focus
        if (!currentFocusable) return;

        debug (Glui_FocusPriority)
        () @trusted {

            import std.string;
            DrawText(format!"%s:d%s"(priority, depth).toStringz, cast(int)box.x, cast(int)box.y, 5, Colors.BLACK);

        }();

        // And it DOES have focus
        if (currentFocusable.isFocused) {

            // Mark the node preceding it to the last encountered focusable node
            previous = last;

            // Clear the next node, so it can be overwritten by a correct value.
            next = null;

            // Reverse priority target
            priorityDirection = -1;

        }

        else {

            // Update positional focus
            updatePositional(currentFocusable, box);

            // There's no node to take focus next, set it now
            if (next is null) next = currentFocusable;

        }


        // Set the current node as the first focusable, if true
        if (first is null) first = currentFocusable;

        // Replace the last
        last = currentFocusable;

    }

    /// Check the given node's position and update `positional` to match.
    private void updatePositional(GluiFocusable node, Rectangle box) {

        // Note: This might give false-positives if the focused node has changed during this frame

        // Check each direction
        foreach (i, ref otherNode; positional) {

            const side = cast(Style.Side) i;
            const dist = distance2(box, side);

            // If a node took this spot before
            if (otherNode !is null) {

                // Ignore if the other node has higher priority
                if (otherNode.priority > priority) continue;

                // If priorities are equal, check if we're closer than the other node
                if (otherNode.priority == priority
                    && otherNode.distance2 < dist) continue;

            }

            // Check if this node matches the direction
            if (checkDirection(box, side)) {

                // Replace the node
                otherNode = WithPriority(priority, dist, node);

            }

        }

    }

    /// Check if the given box is located to the given side of the focus box.
    bool checkDirection(Rectangle box, Style.Side side) {

        // Distance between box sides facing each other.
        //
        // ↓ lastFocusBox  ↓ box
        // +======+        +------+
        // |      |        |      |
        // |      | ~~~~~~ |      |
        // |      |        |      |
        // +======+        +------+
        //   side ↑        ↑ side.reverse
        const distanceExternal = lastFocusBox.getSide(side) - box.getSide(side.reverse);

        // Distance between corresponding box sides.
        //
        // ↓ lastFocusBox  ↓ box
        // +======+        +------+
        // |      |        :      |
        // |      | ~~~~~~~~~~~~~ |
        // |      |        :      |
        // +======+        +------+
        //   side ↑          side ↑
        const distanceInternal = lastFocusBox.getSide(side) - box.getSide(side);

        // The condition for the return value to be true, is for distanceInternal to be greater than distanceExternal.
        // This is not the case in the opposite situation.
        //
        // For example, if we're checking if the box is on the *right* of lastFocusBox:
        //
        // trueish scenario:                                 falseish scenario:
        // Box is to the right of lastFocusBox               Box is the left of lastFocusBox
        //
        // ↓ lastFocusBox  ↓ box                             ↓ box           ↓ lastFocusBox
        // +======+        +------+                          +------+        +======+
        // |      | ~~~~~~ :      | external                 | ~~~~~~~~~~~~~~~~~~~~ | external
        // |      |        :      |    <                     |      :        :      |    >
        // |      | ~~~~~~~~~~~~~ | internal                 |      : ~~~~~~~~~~~~~ | internal
        // +======+        +------+                          +------+        +======+
        //   side ↑        ↑ side.reverse                      side ↑          side ↑
        const condition = abs(distanceInternal) > abs(distanceExternal);

        // ↓ box                    There is an edgecase though. If one box entirely overlaps the other on one axis, we
        // +--------------------+   might end up with unwanted behavior, for example, in a GluiScrollFrame, focus might
        // |   ↓ lastFocusBox   |   switch to the scrollbar instead of a child, as we would normally expect.
        // |   +============+   |
        // |   |            |   |   For this reason, we require both `distanceInternal` and `distanceExternal` to have
        // +---|            |---+   the same sign, as it normally would, but not here.
        //     |            |
        //     +============+       One can still navigate to the `box` using controls for the other axis.
        return condition
            && distanceInternal * distanceExternal >= 0;

    }

    /// Get the square of the distance between given box and `lastFocusBox`.
    float distance2(Rectangle box, Style.Side side) {

        /// Get the center of given rectangle on the axis opposite to the results of getSide.
        float center(Rectangle rect) {

            return side == Style.Side.left || side == Style.Side.right
                ? rect.y + rect.height
                : rect.x + rect.width;

        }

        // Distance between box sides facing each other, see `checkDirection`
        const distanceExternal = lastFocusBox.getSide(side) - box.getSide(side.reverse);

        /// Distance between centers of the boxes on the other axis
        const distanceOpposite = center(box) - center(lastFocusBox);

        return distanceExternal^^2 + distanceOpposite^^2;

    }

}

/// A class for iterating over the node tree.
abstract class TreeAction {

    public {

        /// Node to descend into; `beforeDraw` and `afterDraw` will only be emitted for this node and its children.
        ///
        /// May be null to enable iteration over the entire tree.
        GluiNode startNode;

        /// If true, this action is complete and no callbacks should be ran.
        ///
        /// Overloads of the same callbacks will still be called for the event that prompted stopping.
        bool toStop;

    }

    private {

        /// Set to true once the action has descended into `startNode`.
        bool startNodeFound;

    }

    /// Stop the action
    final void stop() {

        toStop = true;

    }

    // TODO spaw x and xImpl so it matches naming of other interfaces

    /// Called before the tree is drawn. Keep in mind this might not be called if the action is started when tree
    /// iteration has already begun.
    /// Params:
    ///     root     = Root of the tree.
    ///     viewport = Screen space for the node.
    void beforeTree(GluiNode root, Rectangle viewport) { }

    /// Called before each `drawImpl` call of any node in the tree, so supplying parent nodes before their children.
    /// Params:
    ///     node       = Node that's about to be drawn.
    ///     space      = Space given for the node.
    ///     paddingBox = Padding box of the node.
    ///     contentBox = Content box of teh node.
    void beforeDraw(GluiNode node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) { }

    /// ditto
    void beforeDraw(GluiNode node, Rectangle space) { }

    /// internal
    final package void beforeDrawImpl(GluiNode node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) {

        // There is a start node set
        if (startNode !is null) {

            // Check if we're descending into its branch
            if (node is startNode) startNodeFound = true;

            // Continue only if it was found
            else if (!startNodeFound) return;

        }

        // Call the hooks
        beforeDraw(node, space, paddingBox, contentBox);
        beforeDraw(node, space);

    }

    /// Called after each `drawImpl` call of any node in the tree, so supplying children nodes before their parents.
    /// Params:
    ///     node       = Node that's about to be drawn.
    ///     space      = Space given for the node.
    ///     paddingBox = Padding box of the node.
    ///     contentBox = Content box of teh node.
    void afterDraw(GluiNode node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) { }

    /// ditto
    void afterDraw(GluiNode node, Rectangle space) { }

    /// internal
    final package void afterDrawImpl(GluiNode node, Rectangle space, Rectangle paddingBox, Rectangle contentBox) {

        // There is a start node set
        if (startNode !is null) {

            // Check if we're leaving the node
            if (node is startNode) startNodeFound = false;

            // Continue only if it was found
            else if (!startNodeFound) return;
            // Note: We still emit afterDraw for that node, hence `else if`

        }

        afterDraw(node, space, paddingBox, contentBox);
        afterDraw(node, space);
    }

    /// Called after the tree is drawn. Called before input events, so they can safely queue further actions.
    ///
    /// By default, calls `stop()` preventing the action from evaluating during next draw.
    void afterTree() {

        stop();

    }

}

/// Global data for the layout tree.
struct LayoutTree {

    /// Root node of the tree.
    GluiNode root;

    /// Top-most hovered node in the tree.
    GluiNode hover;

    /// Currently focused node.
    ///
    /// Changing this value directly is discouraged. Some nodes might not want the focus! Be gentle, call
    /// `GluiFocusable.focus()` instead and let the node set the value on its own.
    GluiFocusable focus;

    /// Focus direction data.
    FocusDirection focusDirection;

    /// Padding box of the currently focused node. Only available after the node has been drawn.
    ///
    /// See_also: `focusDirection.lastFocusBox`.
    Rectangle focusBox;

    /// Tree actions queued to execute during next draw.
    TreeAction[] actions;

    /// Input strokes bound to emit given action signals.
    InputStroke[][InputActionID] boundInputs;

    /// Check if keyboard input was handled after rendering is has completed.
    bool keyboardHandled;

    /// Current node drawing depth.
    uint depth;

    package uint _disabledDepth;

    /// Current depth of "disabled" nodes, incremented for any node descended into, while any of the ancestors is
    /// disabled.
    deprecated("To be removed in 0.7.0. Use boolean `isBranchDisabled` instead. For iteration depth, check out `depth`")
    @property
    ref inout(uint) disabledDepth() inout return { return _disabledDepth; }

    /// Queue an action to perform while iterating the tree.
    ///
    /// Avoid using this; most of the time `GluiNode.queueAction` is what you want. `LayoutTree.queueAction` might fire
    /// too early
    void queueAction(TreeAction action) {

        actions ~= action;

    }

    /// Restore defaults for given actions.
    void defaultInputBinds() {

        /// Get the ID of an input action.
        auto idOf(alias a)() {

            return InputAction!a.id;

        }

        // Create the binds
        with (GluiInputAction) with (MouseButton) with (KeyboardKey) with (GamepadButton)
        boundInputs = [

            // Basic
            idOf!press: [
                InputStroke(MOUSE_BUTTON_LEFT),
                InputStroke(KEY_ENTER),
                InputStroke(GAMEPAD_BUTTON_RIGHT_FACE_DOWN),
            ],
            idOf!submit: [
                InputStroke(KEY_ENTER),
                InputStroke(GAMEPAD_BUTTON_RIGHT_FACE_DOWN),
            ],
            idOf!cancel: [
                InputStroke(KEY_ESCAPE),
                InputStroke(GAMEPAD_BUTTON_RIGHT_FACE_RIGHT),
            ],

            // Focus
            idOf!focusPrevious: [
                InputStroke(KEY_LEFT_SHIFT, KEY_TAB),
                // TODO: KEY_ANY_SHIFT, KEY_ANY_ALT, KEY_ANY_CONTROL
                // That'd be a blessing. InputStroke could support those special values.
                InputStroke(GAMEPAD_BUTTON_LEFT_TRIGGER_1),
            ],
            idOf!focusNext: [
                InputStroke(KEY_TAB),
                InputStroke(GAMEPAD_BUTTON_RIGHT_TRIGGER_1),
            ],
            idOf!focusLeft: [
                InputStroke(KEY_LEFT),
                InputStroke(GAMEPAD_BUTTON_LEFT_FACE_LEFT),
            ],
            idOf!focusRight: [
                InputStroke(KEY_RIGHT),
                InputStroke(GAMEPAD_BUTTON_LEFT_FACE_RIGHT),
            ],
            idOf!focusUp: [
                InputStroke(KEY_UP),
                InputStroke(GAMEPAD_BUTTON_LEFT_FACE_UP),
            ],
            idOf!focusDown: [
                InputStroke(KEY_DOWN),
                InputStroke(GAMEPAD_BUTTON_LEFT_FACE_DOWN),
            ],

            // Input
            idOf!backspace: [
                InputStroke(KEY_BACKSPACE),
            ],
            idOf!backspaceWord: [
                InputStroke(KEY_LEFT_CONTROL, KEY_BACKSPACE),
                InputStroke(KEY_LEFT_CONTROL, KEY_W),  // emacs & vim
            ],
            idOf!entryPrevious: [
                InputStroke(KEY_UP),
                InputStroke(KEY_LEFT_SHIFT, KEY_TAB),
                InputStroke(KEY_LEFT_CONTROL, KEY_K),  // vim
                InputStroke(KEY_LEFT_CONTROL, KEY_P),  // emacs
                InputStroke(GAMEPAD_BUTTON_LEFT_FACE_UP),
            ],
            idOf!entryNext: [
                InputStroke(KEY_DOWN),
                InputStroke(KEY_TAB),
                InputStroke(KEY_LEFT_CONTROL, KEY_J),  // vim
                InputStroke(KEY_LEFT_CONTROL, KEY_N),  // emacs
                InputStroke(GAMEPAD_BUTTON_LEFT_FACE_DOWN),
            ],
            idOf!entryUp: [
                InputStroke(KEY_LEFT_ALT, KEY_UP),
            ],

            // Scrolling
            idOf!scrollLeft: [
                InputStroke(KEY_LEFT),
                InputStroke(GAMEPAD_BUTTON_LEFT_FACE_LEFT),
            ],
            idOf!scrollRight: [
                InputStroke(KEY_RIGHT),
                InputStroke(GAMEPAD_BUTTON_LEFT_FACE_RIGHT),
            ],
            idOf!scrollUp: [
                InputStroke(KEY_UP),
                InputStroke(GAMEPAD_BUTTON_LEFT_FACE_UP),
            ],
            idOf!scrollDown: [
                InputStroke(KEY_DOWN),
                InputStroke(GAMEPAD_BUTTON_LEFT_FACE_DOWN),
            ],
            idOf!pageLeft: [],
            idOf!pageRight: [],
            idOf!pageUp: [
                InputStroke(KEY_PAGE_UP),
            ],
            idOf!pageDown: [
                InputStroke(KEY_PAGE_DOWN),
            ],
        ];

    }

    /// Remove any inputs bound to given input action.
    /// Returns: `true` if the action was cleared.
    bool clearBoundInput(InputActionID action) {

        return boundInputs.remove(action);

    }

    /// Bind a key stroke or button to given input action. Multiple key strokes are allowed to match given action.
    void bindInput(InputActionID action, InputStroke stroke) {

        boundInputs.require(action) ~= stroke;

    }

    /// Bind a key stroke or button to given input action, replacing any previously bound inputs.
    void bindInputReplace(InputActionID action, InputStroke stroke) {

        boundInputs[action] = [stroke];

    }

    /// Run an action on the tree.
    void runAction(void delegate(TreeAction) @safe fun) {

        import std.range, std.algorithm;

        const leftovers = actions

            // Run each action
            .tee!(a => fun(a))

            // Remove the ones that have finished
            .filter!(a => !a.toStop)
            .moveAll(actions);

        // Remove leftovers
        actions.length -= leftovers.length;

    }

    bool isBranchDisabled;

    /// Scissors stack.
    package Rectangle[] scissors;

    version (Glui_DisableScissors) {

        Rectangle intersectScissors(Rectangle rect) { return rect; }
        void pushScissors(Rectangle) { }
        void popScissors() { }

    }

    else {

        /// Intersect the given rectangle against current scissor area.
        Rectangle intersectScissors(Rectangle rect) {

            import std.algorithm : min, max;

            // No limit applied
            if (!scissors.length) return rect;

            const b = scissors[$-1];

            Rectangle result;

            // Intersect
            result.x = max(rect.x, b.x);
            result.y = max(rect.y, b.y);
            result.w = min(rect.x + rect.w, b.x + b.w) - result.x;
            result.h = min(rect.y + rect.h, b.y + b.h) - result.y;

            return result;

        }

        /// Start scissors mode.
        void pushScissors(Rectangle rect) {

            auto result = rect;

            // There's already something on the stack
            if (scissors.length) {

                // Intersect
                result = intersectScissors(rect);

            }

            // Push to the stack
            scissors ~= result;

            // Start the mode
            applyScissors(result);

        }

        void popScissors() @trusted {

            // Pop the stack
            scissors = scissors[0 .. $-1];

            // Pop the mode
            EndScissorMode();

            // There's still something left
            if (scissors.length) {

                // Start again
                applyScissors(scissors[$-1]);

            }

        }

        private void applyScissors(Rectangle rect) @trusted {

            import glui.utils;

            // End the current mode, if any
            if (scissors.length) EndScissorMode();

            version (Glui_Raylib3) const scale = hidpiScale;
            else                   const scale = Vector2(1, 1);

            // Start this one
            BeginScissorMode(
                to!int(rect.x * scale.x),
                to!int(rect.y * scale.y),
                to!int(rect.w * scale.x),
                to!int(rect.h * scale.y),
            );

        }

    }

}
