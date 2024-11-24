module fluid.io.focus;

import fluid.io.hover;

@safe:

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
