module fluid.tour.text_styling;

import fluid;
import fluid.tour;

@safe:


@(
    () => label("For nodes that contain text, you can set the `fontSize` style property to "
    ~ "change the height of the characters."),
)
Frame fontSizeExample() {
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
    enum TextStyle {
        small,
        large
    }
    
    Theme myTheme = Theme(
        rule!(Label, TextStyle.small)(fontSize = 0.5f),
        rule!(Label, TextStyle.large)(fontSize = 1.5f)
    );
    
    return vframe(
        label(.tags!TextStyle.large, "Large text"),
        label("Regular text"),
        label(.tags!TextStyle.small, "Small text")
    );
}*/