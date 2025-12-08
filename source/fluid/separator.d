/// A line to separate unrelated nodes, or to divide content into groups.
module fluid.separator;

@safe:

/// Use [hseparator] to create horizontal lines, and [vseparator] to create vertical lines.
@("Separator reference example")
unittest {
    import fluid.space;
    import fluid.label;
    run(
        vspace(
            label("Hello"),
            hseparator(),
            label("Goodbye"),
        ),
    );
}

import fluid.node;
import fluid.utils;
import fluid.structs;

import fluid.io.canvas;

/// A [node builder][nodeBuilder] for [Separator][Separator]. The `vseparator` creates a vertical
/// line, while `hseparator` creates a horizontal one.
enum vseparator = NodeBuilder!(Separator, (a) {

    a.isHorizontal = false;
    a.layout = .layout!("center", "fill");

}).init;

/// ditto
enum hseparator = NodeBuilder!(Separator, (a) {

    a.isHorizontal = true;
    a.layout = .layout!("fill", "center");

}).init;

/// A separator node draws a vertical or horizontal line to separate content.
class Separator : Node {

    CanvasIO canvasIO;

    public {

        /// If true, separator draws a horizontal line, otherwise it draws a vertical one.
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
