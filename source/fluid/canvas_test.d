///
module fluid.canvas_test;

import fluid.node;
import fluid.utils;
import fluid.backend;

import fluid.io.canvas;

@safe:

alias canvasTest = nodeBuilder!CanvasTest;

/// This node allows automatically testing if other nodes draw their contents as expected.
class CanvasTest : Node, CanvasIO {

    this() {

    }

    override void resizeImpl(Vector2 space) {

        auto frame = this.implementIO();

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

    }

    override void cropArea(Rectangle area) nothrow {

    }

    override void resetCropArea() nothrow {

    }

    override void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) nothrow {

    }

    override void drawCircle(Vector2 center, float radius, Color color) nothrow {

    }

    override void drawRectangle(Rectangle rectangle, Color color) nothrow {

    }

}
