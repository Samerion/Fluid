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
/// Styles: $(UL
///     $(LI `style` = Default style for this node.)
/// )
class Frame : Space {

    mixin DefineStyles;
    mixin ImplHoveredRect;

    this(T...)(T args) {

        super(args);

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        style.drawBackground(tree.io, outer);

        super.drawImpl(outer, inner);

    }

    protected override inout(Style) pickStyle() inout {

        return style;

    }

}
