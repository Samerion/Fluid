///
module glui.frame;

import raylib;

import glui.space;
import glui.style;
import glui.utils;


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
        style.drawBackground(outer);

        super.drawImpl(outer, inner);

    }

    protected override const(Style) pickStyle() const {

        return style;

    }

}
