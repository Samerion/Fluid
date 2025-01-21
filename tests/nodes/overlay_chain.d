module nodes.overlay_chain;

import fluid;

@safe:

enum overlaySize = Vector2(7, 7);

alias sampleOverlay = nodeBuilder!SampleOverlay;

class SampleOverlay : Node, Overlayable {

    CanvasIO canvasIO;
    Rectangle _anchor;

    this(Rectangle anchor) {
        this.layout = .layout!"fill";
        this._anchor = anchor;
    }

    this(typeof(Rectangle.tupleof) anchor) {
        this.layout = .layout!"fill";
        this._anchor = Rectangle(anchor);
    }

    override Rectangle anchor(Rectangle) const nothrow {
        return _anchor;
    }

    override void resizeImpl(Vector2) {
        require(canvasIO);
        minSize = overlaySize;
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
