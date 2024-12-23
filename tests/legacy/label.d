@Migrated
module legacy.label;

import fluid;
import legacy;

@safe:

@("Label draws text, and updates it if written to")
@Migrated
unittest {

    auto io = new HeadlessBackend;
    auto root = label("Hello, World!");

    with (Rule)
    root.theme = nullTheme.derive(
        rule!Label(textColor = color!"000"),
    );
    root.io = io;
    root.draw();

    const initialTextArea = root.text.size.x * root.text.size.y;

    io.assertTexture(root.text.texture.chunks[0], Vector2(0, 0), color!"fff");
    io.nextFrame;

    root.text ~= " It's a nice day today!";
    root.draw();

    io.assertTexture(root.text.texture.chunks[0], Vector2(0, 0), color!"fff");

    const newTextArea = root.text.size.x * root.text.size.y;

    assert(newTextArea > initialTextArea);

}
