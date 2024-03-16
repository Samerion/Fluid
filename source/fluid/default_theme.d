module fluid.default_theme;

import fluid.node;
import fluid.frame;
import fluid.style;
import fluid.button;
import fluid.slider;
import fluid.backend;
import fluid.checkbox;
import fluid.radiobox;
import fluid.typeface;
import fluid.drag_slot;
import fluid.separator;
import fluid.file_input;
import fluid.text_input;
import fluid.popup_frame;
import fluid.number_input;
import fluid.scroll_input;

/// Theme with no properties set.
///
/// Unlike `Theme.init` or `null`, which will be replaced by fluidDefaultTheme or the parent's theme, this can be used as
/// a valid theme for any node. This makes it useful for automatic tests, since it has guaranteed no margins, padding,
/// or other properties that may confuse the tester.
Theme nullTheme;

/// Default theme that Fluid will use if no theme is supplied. It is a very simple theme that does the minimum to make
/// the role of each node understandable.
Theme fluidDefaultTheme;

static this() {

    Image loadBWImage(string filename)(int width, int height) @trusted {

        import std.array;
        import std.format;
        import std.algorithm;

        const area = width * height;

        auto file = cast(ubyte[]) import(filename);
        auto data = file.map!(a => Color(0, 0, 0, a)).array;

        assert(data.length == area, format!"Wrong %s area %s, expected %s"(filename, data.length, area));

        return Image(data, width, height);

    }

    with (Rule) {

        nullTheme.add(
            rule!Node(),
        );

        fluidDefaultTheme.add(
            rule!Node(
                typeface = Typeface.defaultTypeface,
                textColor = color("#000"),
                selectionBackgroundColor = color("#55b9ff"),
            ),
            rule!Frame(
                backgroundColor = color("#fff"),
            ),
            rule!Button(
                backgroundColor = color("#eee"),
                mouseCursor = FluidMouseCursor.pointer,
                margin.sideY = 2,
                padding.sideX = 6,

                when!"a.isHovered"(backgroundColor = color("#ccc")),
                when!"a.isFocused"(backgroundColor = color("#ddd")),  // TODO use an outline for focus
                when!"a.isPressed"(backgroundColor = color("#aaa")),
                when!"a.isDisabled"(
                    textColor = color("000a"),
                    backgroundColor = color("eee5"),
                    // TODO disabled should apply opacity, and should work for every node
                ),
            ),
            rule!TextInput(
                backgroundColor = color("#fff"),
                borderStyle = colorBorder(color("#aaa")),
                mouseCursor = FluidMouseCursor.text,

                margin.sideY = 2,
                padding.sideX = 6,
                border.sideBottom = 2,

                when!"a.isEmpty"(textColor = color("#000a")),
                when!"a.isFocused"(borderStyle = colorBorder(color("#555")))
                    .otherwise(selectionBackgroundColor = color("#ccc")),
                when!"a.isDisabled"(
                    textColor = color("#000a"),
                    backgroundColor = color("#fff5"),
                ),
            ),
            rule!NumberInputSpinner(
                mouseCursor = FluidMouseCursor.pointer,
                extra = new NumberInputSpinner.Extra(loadBWImage!"arrows-alpha"(40, 64)),
            ),
            rule!AbstractSlider(
                backgroundColor = color("#ddd"),
                lineColor = color("#ddd"),
            ),
            rule!SliderHandle(
                backgroundColor = color("#aaa"),
            ),
            rule!ScrollInput(
                backgroundColor = color("#eee"),
            ),
            rule!ScrollInputHandle(
                backgroundColor = color("#aaa"),

                when!"a.isHovered"(backgroundColor = color("#888")),
                when!"a.isFocused"(backgroundColor = color("#777")),
                when!"a.isPressed"(backgroundColor = color("#555")),
                when!"a.isDisabled"(backgroundColor = color("#aaa5")),
            ),
            rule!PopupFrame(
                border = 1,
                borderStyle = colorBorder(color("#555a")),
            ),
            /*rule!FileInputSuggestion(
                margin = 0,
                backgroundColor = color("#fff"),
                when!"a.isSelected"(backgroundColor = color("#55b9ff"))
            ),*/
            rule!Checkbox(
                margin.sideX = 8,
                margin.sideY = 4,
                border = 1,
                padding = 1,
                borderStyle = colorBorder(color("#555")),
                mouseCursor = FluidMouseCursor.pointer,

                when!"a.isFocused"(backgroundColor = color("#ddd")),
                when!"a.isChecked"(
                    extra = new Checkbox.Extra(loadBWImage!"checkmark-alpha"(64, 50)),
                ),
            ),
            rule!Radiobox(
                margin.sideX = 8,
                margin.sideY = 4,
                border = 0,
                borderStyle = null,
                padding = 2,
                extra = new Radiobox.Extra(1, color("#555"), color("#5550")),

                when!"a.isFocused"(backgroundColor = color("#ddd")),
                when!"a.isChecked"(
                    extra = new Radiobox.Extra(1, color("#555"), color("#000"))
                ),
            ),
            rule!Separator(
                padding = 4,
                lineColor = color("#ccc"),
            ),
            rule!DragSlot(
                padding.sideX = 6,
                padding.sideY = 0,
                border = 1,
                borderStyle = colorBorder(color("#555a")),
                backgroundColor = color("#fff"),
                margin = 4,  // for testing
            ),
            rule!DragHandle(
                lineColor = color("#ccc"),
                padding.sideX = 8,
                padding.sideY = 6,
                extra = new DragHandle.Extra(5),
            ),
        );

    }

}
