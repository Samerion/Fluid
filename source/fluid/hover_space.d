/// 
module fluid.hover_space;

import std.array;

import fluid.node;
import fluid.space;
import fluid.types;
import fluid.utils;

import fluid.io.hover;
import fluid.io.action;

@safe:

alias hoverSpace = nodeBuilder!HoverSpace;

/// A hover space can be used to separate hover in different areas of the user interface, effectively treating them
/// like separate windows. A device node (like a mouse) can be placed to control nodes inside.
///
/// For focus-based nodes like keyboard and gamepad, see `FocusSpace`.
///
/// `HoverSpace` only works with nodes compatible with the new I/O system introduced in Fluid 0.7.2.
class HoverSpace : Space, HoverIO {

    ActionIO actionIO;

    this(Node[] nodes...) {

        super(nodes);

    }

    override int load(Pointer pointer) {
        
        assert(false, "TODO");

    }

    override void emitEvent(Pointer pointer, InputEvent event) {

        assert(false, "TODO");
        
    }

    override int opApply(int delegate(Hoverable) @safe yield) {

        assert(false, "TODO");

    }

    override void resizeImpl(Vector2 space) {

        auto frame = implementIO!HoverSpace();

        use(actionIO);

        super.resizeImpl(space);

    }

}
