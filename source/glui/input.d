///
module glui.input;

import raylib;

import std.meta;
import std.format;

import glui.node;
import glui.style;


@safe:


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
/// Use this interface exclusively for typing, do not subclass it — instead implement GluiInput.
interface GluiFocusable : GluiHoverable {

    /// Take keyboard input.
    bool keyboardImpl();

    /// Set focus to this node.
    ///
    /// Implementation would usually assign `tree.focus` to self for this to take effect. It is legal, however, for this
    /// method to redirect the focus at another node (by calling its `focus()` method), or ignore the request.
    void focus();

    /// Check if this node has focus. Recommended implementation: `return tree.focus is this`
    bool isFocused() const;

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
