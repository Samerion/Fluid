@Migrated
module legacy.size_lock;

import fluid;
import legacy;

@safe:

@("SizeLock reduces the amount of space a node gets")
@Migrated
unittest {

    auto io = new HeadlessBackend;
    auto root = sizeLock!vframe(
        layout!("center", "fill"),
        sizeLimitX(400),
        label("Hello, World!"),
    );

    root.io = io;

    with (Rule)
    root.theme = nullTheme.derive(
        rule!Frame(backgroundColor = color!"1c1c1c"),
        rule!Label(textColor = color!"eee"),
    );

    {
        root.draw();

        // The rectangle should display neatly in the middle of the display, limited to 400px
        io.assertRectangle(Rectangle(200, 0, 400, 600), color!"1c1c1c");
    }

    {
        io.nextFrame;
        root.layout = layout!("start", "fill");
        root.updateSize();
        root.draw();

        io.assertRectangle(Rectangle(0, 0, 400, 600), color!"1c1c1c");
    }

    {
        io.nextFrame;
        root.layout = layout!"center";
        root.limit = sizeLimit(200, 200);
        root.updateSize();
        root.draw();

        io.assertRectangle(Rectangle(300, 200, 200, 200), color!"1c1c1c");
    }

}
