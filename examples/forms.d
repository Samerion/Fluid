module fluid.showcase.forms;

import std.range;

import fluid;
import fluid.showcase;


@safe:


Space myExample() {

    Slider!string stringSlider;
    Label stringSliderLabel;

    auto group = new RadioboxGroup;

    return vspace(

        fieldSlot!vframe(
            label("Username"),
            textInput(),
        ),
        fieldSlot!vframe(
            label("Integer"),
            intInput(),
        ),
        fieldSlot!vframe(
            label("Real number"),
            floatInput(),
        ),

        fieldSlot!hframe(
            checkbox(),
            label("Accept my rules"),
        ),
        fieldSlot!hframe(
            checkbox(),
            label("Accept spam"),
        ),

        label("Choose the pizza"),

        fieldSlot!hframe(
            radiobox(group),
            label("Pizza"),
        ),
        fieldSlot!hframe(
            radiobox(group),
            label("Frog"),
        ),
        fieldSlot!hframe(
            radiobox(group),
            label("Island"),
        ),

        fieldSlot!vframe(
            .layout!"fill",

            label("Int slider"),
            slider!int(
                .layout!"fill",
                iota(0, 3),
            ),
        ),
        fieldSlot!vframe(
            .layout!"fill",

            label("Float slider"),
            slider!float(
                .layout!"fill",
                iota(0.0f, 1.0f, 0.1f),
            ),
        ),
        fieldSlot!vframe(
            .layout!"fill",

            hspace(
                .layout!"fill",
                label("Factor slider"),
                stringSliderLabel = label(
                    .layout!(1, "end"),
                    ""
                ),
            ),

            stringSlider = slider!string(
                .layout!"fill",
                only("Never", "Not likely", "Uncertain", "Likely", "Definitely"),
                2,
                delegate {
                    import std.conv;
                    stringSliderLabel.text = stringSlider.value.text;
                }
            ),
        ),
    );

}
