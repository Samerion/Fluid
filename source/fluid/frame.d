///
module fluid.frame;

import fluid.space;
import fluid.style;
import fluid.utils;
import fluid.backend;


@safe:


/// Make a new vertical frame.
alias vframe = simpleConstructor!Frame;

/// Make a new horizontal frame.
alias hframe = simpleConstructor!(Frame, (a) {

    a.directionHorizontal = true;

});

/// This is a frame, a stylized container for other nodes.
class Frame : Space {

    this(T...)(T args) {

        super(args);

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        style.drawBackground(tree.io, outer);

        super.drawImpl(outer, inner);

    }

    protected override bool hoveredImpl(Rectangle rect, Vector2 mousePosition) {

        import fluid.node;

        return Node.hoveredImpl(rect, mousePosition);

    }

}
