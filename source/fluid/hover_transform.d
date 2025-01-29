module fluid.hover_transform;

import std.array;

import fluid.types;
import fluid.utils;
import fluid.node_chain;

import fluid.io.hover;

@safe:

alias hoverTransform = nodeBuilder!HoverTransform;

class HoverTransform : NodeChain, HoverIO {

    HoverIO hoverIO;

    public {

        /// Rectangle for hover input. This input will be transformed to
        /// the rectangle spanned by this system.
        Rectangle sourceRectangle;

    }

    private {

        /// Pointers received from the host.
        Appender!(Pointer[]) pointers;

    }

    /// Params:
    ///     sourceRectangle = Rectangle the input is expected to fit in.
    this(Rectangle sourceRectangle) {
        this.sourceRectangle = sourceRectangle;
    }

    override void beforeResize(Vector2) {
        require(hoverIO);
        this.controlIO().startAndRelease();
    }

    override void afterResize(Vector2) {
        this.controlIO().stop();
    }

    /// `HoverTransform` saves all the pointers it receives from the host `HoverIO`
    /// and creates local copies. It then transforms those, and checks its children for
    /// matching nodes.
    override void beforeDraw(Rectangle outer, Rectangle inner) {

        pointers.clear();
        foreach (HoverPointer pointer; hoverIO) {
            pointers ~= Pointer(pointer);
        }

    }

    override int load(HoverPointer pointer) {
        assert(false, "TODO");
    }

    inout(HoverPointer) fetch(int number) inout {
        assert(false, "TODO");
    }

    void emitEvent(HoverPointer pointer, InputEvent event) {
        assert(false, "TODO");
    }

    inout(Hoverable) hoverOf(HoverPointer pointer) inout {
        assert(false, "TODO");
    }

    inout(HoverScrollable) scrollOf(HoverPointer pointer) inout {
        assert(false, "TODO");
    }

    bool isHovered(const Hoverable hoverable) const {
        assert(false, "TODO");
    }

    int opApply(int delegate(HoverPointer) @safe yield) {
        assert(false, "TODO");
    }

    int opApply(int delegate(Hoverable) @safe yield) {
        assert(false, "TODO");
    }

}

private struct Pointer {

    /// Pointer given by the hover transform.
    HoverPointer source;

}
