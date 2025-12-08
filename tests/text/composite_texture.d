module text.composite_texture;

import std.conv;
import std.range;
import std.algorithm;

import fluid;

@safe:

unittest {

    auto content = label(
        .nullTheme,
        "One\nTwo\nThree\nFour\nFive\n"
    );
    auto root = testSpace(
        vscrollFrame(content)
    );

    root.draw();

    // One chunk only
    assert(content.text.texture.chunks.length == 1);

    // This one chunk must have been drawn
    root.drawAndAssert(
        content.drawsImage(content.text.texture.chunks[0].image).at(0, 0).ofColor("#fff")
    );

}

@("Only visible chunks are rendered")
unittest {

    enum chunkSize = CompositeTexture.maxChunkSize;

    auto content = label(
        "One\nTwo\nThree\nFour\nFive\n"
    );
    auto viewport = vscrollFrame(content);
    auto root = sizeLock!testSpace(
        .sizeLimit(800, 200),
        .cropViewport,
        .nullTheme,
        viewport
    );

    // Add a lot more text
    content.text = content.text.repeat(30).joiner.text;
    root.draw();

    const textSize = content.text.size;

    // Make sure assumptions for this test are sound:
    assert(textSize.y > chunkSize * 2, "Generated text must span at least three chunks");
    assert(root.limit.y < chunkSize,  "Window size must be smaller than chunk size");

    // Three chunks, only the first one is drawn and generated
    assert(content.text.texture.chunks.length >= 3);
    assert(content.text.texture.chunks[0].isValid);
    assert(content.text.texture.chunks[1 .. $].all!((ref a) => !a.isValid));
    root.drawAndAssert(
        content.drawsImage(content.text.texture.chunks[0].image).at(0, 0).ofColor("#fff"),
        content.doesNotDraw(),
    );

    // Scroll just enough so that both chunks should be on screen
    // This should cause the second chunk to generate too
    viewport.scroll = chunkSize - 1;
    root.draw();
    assert(content.text.texture.chunks[0 .. 2].all!((ref a) => a.isValid));
    assert(content.text.texture.chunks[2 .. $].all!((ref a) => !a.isValid));

    root.drawAndAssert(
        content.drawsImage(content.text.texture.chunks[0].image)
            .at(0, -viewport.scroll)
            .ofColor("#fff"),
        content.drawsImage(content.text.texture.chunks[1].image)
            .at(0, -viewport.scroll + chunkSize)
            .ofColor("#fff"),
        content.doesNotDraw(),
    ),

    // Skip to third chunk, force regeneration
    viewport.scroll = 2 * chunkSize - 1;
    root.updateSize();
    root.draw();

    // Because of the resize, the first chunk must have been destroyed
    assert(content.text.texture.chunks[0 .. 1].all!((ref a) => !a.isValid));
    assert(content.text.texture.chunks[1 .. 3].all!((ref a) => a.isValid));
    assert(content.text.texture.chunks[3 .. $].all!((ref a) => !a.isValid));

    root.drawAndAssert(
        content.drawsImage(content.text.texture.chunks[1].image)
            .at(0, -viewport.scroll + chunkSize)
            .ofColor("#fff"),
        content.drawsImage(content.text.texture.chunks[2].image)
            .at(0, -viewport.scroll + chunkSize*2)
            .ofColor("#fff"),
        content.doesNotDraw(),
    );

}
