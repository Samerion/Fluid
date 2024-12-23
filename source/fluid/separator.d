///
module fluid.separator;

import fluid.node;
import fluid.utils;
import fluid.backend;
import fluid.structs;

import fluid.io.canvas;

@safe:


/// A separator node creates a line, used to separate unrelated parts of content.
alias vseparator = simpleConstructor!(Separator, (a) {

    a.isHorizontal = false;
    a.layout = .layout!("center", "fill");

});

/// ditto
alias hseparator = simpleConstructor!(Separator, (a) {

    a.isHorizontal = true;
    a.layout = .layout!("fill", "center");

});

/// ditto
class Separator : Node {

    CanvasIO canvasIO;

    public {

        bool isHorizontal;

    }

    override void resizeImpl(Vector2) {

        use(canvasIO);
        minSize = Vector2(1, 1);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        auto style = pickStyle();

        style.drawBackground(io, canvasIO, outer);

        if (isHorizontal) {

            auto start = Vector2(start(inner).x, center(inner).y);
            auto end = Vector2(end(inner).x, center(inner).y);

            style.drawLine(io, canvasIO, start, end);

        }

        else {

            auto start = Vector2(center(inner).x, start(inner).y);
            auto end = Vector2(center(inner).x, end(inner).y);

            style.drawLine(io, canvasIO, start, end);

        }

    }

}
