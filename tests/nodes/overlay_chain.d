module nodes.overlay_chain;

import fluid;

@safe:

alias sampleOverlay = nodeBuilder!SampleOverlay;
alias relativeOverlay = nodeBuilder!(SampleOverlay, (a) {
    a.isRelative = true;
});

class SampleOverlay : Node, Overlayable {

    CanvasIO canvasIO;
    Rectangle _anchor;
    Vector2 size;
    bool isRelative;

    this(Vector2 size, Rectangle anchor) {
        this.layout = .layout!"fill";
        this.size = size;
        this._anchor = anchor;
    }

    override Rectangle anchor(Rectangle viewport) const nothrow {
        if (isRelative) {
            return Rectangle(
                (viewport.start + _anchor.start).tupleof,
                _anchor.size.tupleof,
            );
        }
        else {
            return _anchor;
        }
    }

    override void resizeImpl(Vector2) {
        require(canvasIO);
        minSize = size;
    }

    override void drawImpl(Rectangle, Rectangle inner) {
        canvasIO.drawRectangle(inner, color("#000"));
    }

    alias opEquals = typeof(super).opEquals;

    override bool opEquals(const Object object) const {
        return super.opEquals(object);
    }

}

@("OverlayChain can draw a number of different overlays")
unittest {

    enum overlaySize = Vector2(7, 7);

    auto label = label("Under overlay");
    auto chain = overlayChain(label);
    auto root = sizeLock!testSpace(
        .sizeLimit(100, 100),
        .nullTheme,
        chain
    );

    root.drawAndAssert(
        chain.drawsChild(label),
        chain.doesNotDrawChildren(),
    );

    auto firstOverlay = sampleOverlay(
        .layout!"start",
        overlaySize,
        Rectangle(50, 50, 10, 10)
    );

    chain.addOverlay(firstOverlay);
    root.drawAndAssert(
        label.isDrawn(),
        firstOverlay.isDrawn(),
        firstOverlay.drawsRectangle(60, 60, overlaySize.tupleof),
    );

    auto secondOverlay = sampleOverlay(
        .layout!"start",
        overlaySize,
        Rectangle(100, 100, 0, 0)
    );
    chain.addOverlay(secondOverlay);
    root.drawAndAssert(
        label.isDrawn(),
        firstOverlay.isDrawn(),
        firstOverlay.drawsRectangle(60, 60, overlaySize.tupleof),
        secondOverlay.drawsRectangle(100, 100, overlaySize.tupleof),
    );

}

@("Overlays in OverlayChain can be aligned with NodeAlign")
unittest {

    enum overlaySize = Vector2(7, 7);

    auto chain = overlayChain();
    auto root = testSpace(chain);

    const centerTarget = Vector2(55, 55) - overlaySize/2;
    auto centerOverlay = sampleOverlay(
        .layout!"center",
        overlaySize,
        Rectangle(50, 50, 10, 10),
    );
    chain.addOverlay(centerOverlay);

    const endTarget = Vector2(50, 50) - overlaySize;
    auto endOverlay = sampleOverlay(
        .layout!"end",
        overlaySize,
        Rectangle(50, 50, 10, 10),
    );
    chain.addOverlay(endOverlay);

    root.drawAndAssert(
        centerOverlay.drawsRectangle(centerTarget.tupleof, overlaySize.tupleof),
        endOverlay.drawsRectangle(endTarget.tupleof, overlaySize.tupleof),
    );

}

@("In OverlayChain, NodeAlign.fill chooses alignment based on available space")
unittest {

    auto chain = overlayChain(
        .layout!(1, "fill")
    );
    auto root = sizeLock!testSpace(
        .sizeLimit(100, 100),
        chain
    );

    auto smallOverlay = sampleOverlay(
        Vector2(25, 25),
        Rectangle(40, 40, 20, 20),
    );
    chain.addOverlay(smallOverlay);

    auto cornerOverlay = sampleOverlay(
        Vector2(32, 32),
        Rectangle(40, 40, 40, 40),
    );
    chain.addOverlay(cornerOverlay);

    auto edgeOverlay = sampleOverlay(
        Vector2(32, 32),
        Rectangle(60, 50, 20, 0),
    );
    chain.addOverlay(edgeOverlay);

    auto bigOverlay = sampleOverlay(
        Vector2(80, 80),
        Rectangle(20, 20, 20, 20),
    );
    chain.addOverlay(bigOverlay);

    root.drawAndAssert(
        smallOverlay.drawsRectangle(60, 60, 25, 25),
        cornerOverlay.drawsRectangle(8, 8, 32, 32),
        edgeOverlay.drawsRectangle(28, 50, 32, 32),
        bigOverlay.drawsRectangle(-10, -10, 80, 80),
    );

}

@("OverlayChain allows using different alignment per axis")
unittest {

    auto chain = overlayChain(
        .layout!(1, "fill")
    );
    auto root = testSpace(chain);

    SampleOverlay[] overlays;

    foreach (x; [NodeAlign.start, NodeAlign.center, NodeAlign.end]) {
        foreach (y; [NodeAlign.start, NodeAlign.center, NodeAlign.end]) {

            overlays ~= sampleOverlay(
                .layout(x, y),
                Vector2(32, 16),
                Rectangle(0, 0, 10, 20),
            );
            chain.addOverlay(overlays[$-1]);

        }
    }

    root.drawAndAssert(
        // (start, _)
        overlays[0].drawsRectangle( 10,  20, 32, 16),  // start
        overlays[1].drawsRectangle( 10,   2, 32, 16),  // center
        overlays[2].drawsRectangle( 10, -16, 32, 16),  // end

        // (center, _)
        overlays[3].drawsRectangle(-11,  20, 32, 16),  // start
        overlays[4].drawsRectangle(-11,   2, 32, 16),  // center
        overlays[5].drawsRectangle(-11, -16, 32, 16),  // end

        // (end, _)
        overlays[6].drawsRectangle(-32,  20, 32, 16),  // start
        overlays[7].drawsRectangle(-32,   2, 32, 16),  // center
        overlays[8].drawsRectangle(-32, -16, 32, 16),  // end
     );

}

@("Overlays in OverlayChain can move without a resize")
unittest {

    auto chain = overlayChain(
        .layout!(1, "fill")
    );
    auto root = testSpace(chain);
    auto overlay = sampleOverlay(
        .layout!"start",
        Vector2(32, 32),
        Rectangle(0, 0, 0, 0),
    );
    chain.addOverlay(overlay);

    root.drawAndAssert(
        overlay.drawsRectangle(0, 0, 32, 32),
    );

    overlay._anchor = Rectangle(-16, -16, 0, 0),
    root.drawAndAssert(
        overlay.drawsRectangle(-16, -16, 32, 32),
    );

    overlay._anchor = Rectangle(400, 400, 0, 0),
    root.drawAndAssert(
        overlay.drawsRectangle(400, 400, 32, 32),
    );

}

@("OverlayChain overlays can be positioned relative to screen, or to the chain")
unittest {

    auto chain = overlayChain(
        .layout!(1, "fill")
    );
    auto root = sizeLock!vtestSpace(
        .sizeLimit(300, 300),
        vspace(.layout!1),
        chain,
        vspace(.layout!1),
    );
    auto absolute = sampleOverlay(
        .layout!"start",
        Vector2(32, 32),
        Rectangle(0, 0, 0, 0),
    );
    auto relative = relativeOverlay(
        .layout!"start",
        Vector2(32, 32),
        Rectangle(0, 0, 0, 0),
    );

    chain.addOverlay(absolute);
    chain.addOverlay(relative);

    root.drawAndAssert(
        absolute.drawsRectangle(0,   0, 32, 32),
        relative.drawsRectangle(0, 100, 32, 32),
    );

}
