///
module glui.input;

import raylib;

import std.meta;

import glui.node;
import glui.style;


@safe:


/// An interface to be implemented by all nodes that can take focus.
///
/// Use this interface exclusively for typing, do not subclass it — instead implement GluiInput.
interface GluiFocusable {

    void mouseImpl();
    bool keyboardImpl();
    ref inout(bool) isDisabled() inout;
    void focus();
    bool isFocused() const;

    /// Check if the given node implements GluiFocusable and isn't disabled, and return it. If it's not, returns `null`.
    static inout(GluiFocusable) check(inout GluiNode node) {

        // Check if it's focusable
        if (auto focus = cast(inout GluiFocusable) node) {

            // Return it, but not if it's disabled
            return focus.isDisabled ? null : focus;

        }

        else return null;

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

    mixin DefineStyles!(
        "focusStyle", q{ style },
        "hoverStyle", q{ style },
        "disabledStyle", q{ style },
    );

    /// Callback to run when the input value is altered.
    void delegate() changed;

    /// Callback to run when the input is submitted.
    void delegate() submitted;

    this(T...)(T sup) {

        super(sup);

    }

    override ref inout(bool) isDisabled() inout { return super.isDisabled; }

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
