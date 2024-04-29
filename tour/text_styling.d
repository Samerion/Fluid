module fluid.tour.text_styling;

import fluid;
import fluid.tour;

@safe:


@(
    () => label("For nodes that contain text, you can set the `textSize` style property to "
    ~ "change the height of the characters."),
)
Frame textSizeExample() {
    return vframe(
        label("Large text", 20f),
        label("Regular text", 12f),
        label("Small text", 8f),
        label("Default text")
    );
}
/*
@(
    () => label("Ideally, you should make a theme with style tags for setting text sizes."),
)
Frame textTagsExample() {
    Theme myTheme = Theme(
        rule!(Label, 1)(textSize: 0.5f),
        rule!(Label, 3)(textSize: 1.5f)
    );
    
    return vframe(
        label("Large text", 2f),
        label("Regular text", 16f),
        label("Small text", 0.5f)
    );
}*/