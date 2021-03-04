///
module glui.input;

import raylib;

import std.meta;

import glui.node;
import glui.structs;
import glui.style;

/// Represents a general input node.
///
/// Styles: $(UL
///     $(LI `styleKey` = Default style for the input.)
///     $(LI `focusStyleKey` = Style for when the input is focused.)
///     $(LI `disabledStyleKey` = Style for when the input is disabled.)
/// )
abstract class GluiInput(Parent : GluiNode) : Parent, GluiFocusable {

    /// Style property is present
    static if (__traits(hasMember, typeof(this), "style")) {

        // Leave it original
        mixin DefineStyles!(
            "focusStyle", q{ style },
            "disabledStyle", q{ style },
        );

    }

    // Define it
    else mixin DefineStyles!(
        "style", q{ Style.init },
        "focusStyle", q{ style },
        "disabledStyle", q{ style },
    );

    /// Callback to run when the input value is altered.
    void delegate() changed;

    /// Callback to run when the input is submitted.
    void delegate() submitted;

    ///
    bool disabled;

    this(T...)(T sup) {

        super(sup);

    }

    /// Change the focus to this node.
    void focus() {

        tree.focus = this;

    }

}
