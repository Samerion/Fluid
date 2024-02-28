///
module fluid.separator;

import fluid.node;
import fluid.utils;
import fluid.backend;
import fluid.structs;


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

    public {

        bool isHorizontal;

    }

    override void resizeImpl(Vector2) {

        minSize = Vector2(1, 1);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        auto style = pickStyle();

        style.drawBackground(io, outer);

        if (isHorizontal) {

            auto start = Vector2(start(inner).x, center(inner).y);
            auto end = Vector2(end(inner).x, center(inner).y);

            style.drawLine(io, start, end);

        }

        else {

            auto start = Vector2(center(inner).x, start(inner).y);
            auto end = Vector2(center(inner).x, end(inner).y);

            style.drawLine(io, start, end);

        }

    }

}

unittest {

    import fluid.theme;
    import fluid.default_theme;

    auto io = new HeadlessBackend(Vector2(100, 100));
    auto theme = nullTheme.derive(
        rule!Separator(
            lineColor = color("#000"),
        ),
    );

    // Vertical
    auto root = vseparator(theme);

    root.backend = io;
    root.draw();

    io.assertLine(Vector2(50, 0), Vector2(50, 100), color("#000"));

    // Horizontal
    root = hseparator(theme);

    io.nextFrame;
    root.backend = io;
    root.draw();

    io.assertLine(Vector2(0, 50), Vector2(100, 50), color("#000"));

}
