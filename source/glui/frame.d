///
module glui.frame;

import glui.space;
import glui.style;
import glui.utils;
import glui.backend;


@safe:


/// Make a new vertical frame.
alias vframe = simpleConstructor!GluiFrame;

/// Make a new horizontal frame.
alias hframe = simpleConstructor!(GluiFrame, (a) {

    a.directionHorizontal = true;

});

/// This is a frame, a stylized container for other nodes.
/// Styles: $(UL
///     $(LI `style` = Default style for this node.)
/// )
class GluiFrame : GluiSpace {

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
