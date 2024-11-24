/// Implements a baseline for hover-based input, like mouse and pen tablets.
module fluid.io.hover;

import fluid.node;
import fluid.tree.input_action;

@safe:

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
    ///     if (active && id == inputActionID!(FluidInputAction.press)) {
    ///
    ///         // use `run...Impl` to prevent recursion
    ///         return runInputActionImpl!(FluidInputAction.submit);
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

    final bool runInputActionImpl(alias action)(bool active = true) {

        return runInputActionImpl(inputActionID!action, active);

    }

    final bool runInputAction(immutable InputActionID action, bool active = true) {

        // The programmer may override the action
        if (inputActionImpl(action, active)) return true;

        return runInputActionImpl(action, active);

    }

    final bool runInputAction(alias action)(bool active = true) {

        return runInputAction(inputActionID!action, active);

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
        import fluid.io.hover;
        import fluid.tree.input_action;

        static assert(is(typeof(this) : Node),
            format!"%s : FluidHoverable must inherit from Node"(typeid(this)));

        // Provide a default implementation of inputActionImpl
        static if (!is(typeof(super) : FluidHoverable))
        bool inputActionImpl(immutable InputActionID id, bool active) {

            return false;

        }

        override bool runInputActionImpl(immutable InputActionID action, bool active) {

            import std.meta : Filter;

            alias This = typeof(this);

            bool handled;

            // Check each member
            static foreach (memberName; __traits(allMembers, This)) {

                static if (!__traits(isDeprecated, __traits(getMember, This, memberName)))
                static foreach (overload; __traits(getOverloads, This, memberName)) {

                    // Find the matching action
                    static foreach (actionType; __traits(getAttributes, overload)) {

                        // Input action
                        static if (isInputAction!actionType) {
                            if (inputActionID!actionType == action) {

                                // Run the action if the stroke was performed
                                if (shouldActivateWhileDown!overload || active) {

                                    handled = runInputActionHandler(actionType, &__traits(child, this, overload));

                                }

                            }
                        }

                        // Prevent usage via @InputAction
                        else static if (is(typeof(actionType)) && isInstanceOf!(typeof(actionType), InputAction)) {

                            static assert(false,
                                format!"Please use @(%s) instead of @InputAction!(%1$s)"(actionType.type));

                        }

                    }

                }

            }

            return handled;

        }

    }

}

bool runInputActionsImpl(FluidHoverable hoverable, bool mouse) {

    import fluid.tree.input_mapping;

    auto tree = hoverable.asNode.tree;
    bool handled;

    // Run all active actions
    if (!mouse || hoverable.isHovered)
    foreach_reverse (event; tree.activeActions[]) {

        if (event.isMouse != mouse) continue;

        handled = hoverable.runInputAction(event.action, true) || handled;

        // Stop once handled
        if (handled) break;

    }

    // Run all "while down" actions
    foreach (event; tree.downActions[]) {

        if (event.isMouse != mouse) continue;

        handled = hoverable.runInputAction(event.action, false) || handled;

    }

    return handled;

}
