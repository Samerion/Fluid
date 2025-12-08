module text.text;

@safe:

import fluid;
import std.string;
import std.format;
import std.range;

Theme testTheme;

static this() {
    testTheme = nullTheme.derive(
        rule!TextInput(
            Rule.textColor = color("#000"),
            Rule.backgroundColor = color("#faf"),
            Rule.selectionBackgroundColor = color("#02a"),
            Rule.fontSize = 14.pt,
        ),
    );
}

@("Text can be used with, or without specifying styles")
unittest {

    import fluid.space;

    Style[2] styles;
    auto root = vspace();
    auto styleMap = [
        TextStyleSlice(0, 0, 1),
    ];
    auto text = mapText(root, "Hello, World!", styleMap);

    root.draw();
    text.resize();
    text.draw(styles, Vector2(0, 0));

}

version (unittest) {

    mixin template indexAtTest() {

        void test(size_t expected, Vector2 position) {

            const index = root.text.indexAt(position);

            if (index == expected) {
                io.drawPointer(position, color("#0a0"));
            }
            else {
                io.drawPointer(position);
                io.saveSVG("/tmp/fluid.svg");
                debug assert(false, format!"Expected %s, got %s"(expected, index));
            }

        }

    }

}

@("Text.indexAt works with multiple lines of text")
unittest {

    // This test depends on specific properties of the default typeface

    import fluid.label;
    import std.stdio;

    auto root = label(testTheme, "Hello, World!\nHi, Globe!\nWelcome, Fluid user!");
    auto io = new HeadlessBackend;
    root.io = io;
    root.draw();

    mixin indexAtTest;

    const lineHeight = root.style.getTypeface.lineHeight;

    // First line
    test( 0, Vector2(  0, 0));
    test( 1, Vector2( 10, 0));
    test( 3, Vector2( 30, lineHeight/2));
    test( 7, Vector2( 60, lineHeight/3));
    test( 8, Vector2( 70, lineHeight/3));
    test(12, Vector2(104, lineHeight/3));
    test(13, Vector2(108, lineHeight/3));
    test(13, Vector2(140, lineHeight/3));

    // Second line
    test(14, Vector2(4, lineHeight * 1.5));
    test(19, Vector2(40, lineHeight * 1.1));
    test(24, Vector2(400, lineHeight * 1.9));

    // Third line
    test(29, Vector2( 40, lineHeight * 2.1));
    test(32, Vector2( 80, lineHeight * 2.9));
    test(38, Vector2(120, lineHeight * 2.5));
    test(45, Vector2(180, lineHeight * 2.2));
    test(45, Vector2(220, lineHeight * 2.6));

    // Before it all
    test( 0, Vector2(  0, -20));
    test( 1, Vector2( 10, -40));
    test( 3, Vector2( 30, -5));
    test( 7, Vector2( 60, -60));
    test( 8, Vector2( 70, -80));
    test(12, Vector2(104, -90));
    test(13, Vector2(108, -25));
    test(13, Vector2(140, -12));

}

@("Text.indexAt works correctly with blank lines")
unittest {

    // This test depends on specific properties of the default typeface

    import fluid.label;
    import std.stdio;

    auto root = label(nullTheme, "\r\nHello,\n\nWorld!\n");
    auto io = new HeadlessBackend;
    root.io = io;
    root.draw();

    mixin indexAtTest;

    const lineHeight = root.style.getTypeface.lineHeight;

    // First line — all point to zero
    test(0, Vector2(-40, lineHeight*0.5));
    test(0, Vector2(  0, 0));
    test(0, Vector2( 60, lineHeight*0.3));
    test(0, Vector2(140, lineHeight*0.8));

    // Second line
    test(2, Vector2(0,   lineHeight*1.1));
    test(8, Vector2(50,  lineHeight*1.8));
    test(8, Vector2(200, lineHeight*1.1));

    // Third line — empty
    test(9, Vector2(-100, lineHeight*2.4));
    test(9, Vector2(0,    lineHeight*2.3));
    test(9, Vector2(100,  lineHeight*2.9));

    // Fourth line
    // TODO test(10, Vector2(-100, lineHeight*3.4));
    test(10, Vector2(0,    lineHeight*3.3));
    test(16, Vector2(100,  lineHeight*3.9));

    // Fifth line — empty
    test(17, Vector2(-100, lineHeight*4.9));
    test(17, Vector2(0,    lineHeight*4.5));
    test(17, Vector2(100,  lineHeight*4.1));

    // Beyond — empty
    test(17, Vector2(-100, lineHeight*5.9));
    test(17, Vector2(0,    lineHeight*5.5));
    test(17, Vector2(100,  lineHeight*5.1));

}

@("Overflowing text does not break layout")
unittest {

    import fluid.label;

    const longText = "helloworld".repeat(100).join;

    auto root = label(.testTheme, longText);
    root.draw();

    const startRuler = root.text.rulerAt(0);
    const endRuler = root.text.rulerAt(longText.length);

    assert(startRuler.penPosition.y == endRuler.penPosition.y);

}

@("Text updates its size when editing")
unittest {

    import fluid.label;

    auto root = label(
        `return vframe(\n` ~
        `    label("First line"),\n` ~
        `    label("Second line"),\n` ~
        `    label("Third line"),\n` ~
        `);`
    );

    root.draw();

    const index = root.text.byChar.indexOf(`\n    label("Third line")`);
    const firstTextSize = root.text.size;

    root.text.replace(index, index, "asdfg");
    root.draw();

    const secondTextSize = root.text.size;

    assert(firstTextSize.x < secondTextSize.x);
    assert(firstTextSize.y == secondTextSize.y);

}

@("Text rendering is consistent for large text")
unittest {

    import std.file;
    import fluid.label;

    const source = Rope.merge(Rope("the quick brown fox jumps over the lazy dog. ").repeat(100).array);
    const fontSize = 10;

    auto theme = .testTheme.derive(
        rule!Node(
            Rule.fontSize = fontSize,
        ),
    );
    auto io = new HeadlessBackend(Vector2(200, 1000));
    auto root = label(theme, source);
    auto text = root.text;

    const space = io.windowSize;

    root.io = io;
    theme.apply(root, root.style);
    text.hasFastEdits = true;
    text.resize(space);

    assert(text.node.pickStyle.fontSize == fontSize);

    Image[2] backImages;
    Image[2] frontImages;

    // Draw the first two textures separately
    foreach_reverse (i, ref chunk; text.texture.chunks[0..2]) {

        const position = text.texture.chunkPosition(i);

        text.generate(only(i));
        text.texture.upload(io, i, io.dpi);
        chunk.texture.draw(position);

        // Move the image to the list
        backImages[i] = chunk.image;
        chunk = chunk.init;

    }

    io.nextFrame;
    text.resize(space);
    text.clearTextures(io.dpi);

    // Now render both at once
    text.generate(only(0, 1));

    foreach (i, ref chunk; text.texture.chunks[0..2]) {

        const position = text.texture.chunkPosition(i);

        text.texture.upload(io, i, io.dpi);
        chunk.texture.draw(position);

        // Move the image to the list
        frontImages[i] = chunk.image;
        chunk = chunk.init;

    }

    assert(frontImages[] == backImages[], "Two separately rendered pieces of text should look identical");

}
