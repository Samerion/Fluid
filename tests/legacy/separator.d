@Migrated
module legacy.separator;

import fluid;
import legacy;

@safe:

@("vseparator draws a vertical line, hseparator draws a horizontal line")
@Migrated
unittest {

    import fluid.theme;

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
