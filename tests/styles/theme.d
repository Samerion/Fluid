module styles.theme;

import fluid;
import fluid.theme;

@safe:

@("Themes can be applied to Node")
unittest {

    Theme theme;

    with (Rule)
    theme.add(
        rule!Label(
            textColor = color!"#abc",
        ),
    );

    auto content = label("placeholder");
    auto root = testSpace(theme, content);

    root.draw();
    assert(content.text.texture.chunks[0].image.palette[0] == color("#abc"));
    root.drawAndAssert(
        content.drawsImage().ofColor("#fff"),
    );

}

@("Theme rules can be applied to Style")
@system unittest {

    auto frameRule = rule!Frame(
        Rule.margin.sideX = 8,
        Rule.margin.sideY = 4,
    );
    auto theme = nullTheme.derive(frameRule);

    // Test selector
    assert(frameRule.selector.type == typeid(Frame));
    assert(frameRule.selector.tags.empty);

    // Test fields
    auto style = Style.init;
    frameRule.apply(vframe(), style);
    assert(style.margin == [8, 8, 4, 4]);
    assert(style.padding == style.init.padding);
    assert(style.textColor == style.textColor.init);

    // No dynamic rules
    assert(rule.styleDelegate is null);

    auto root = vframe(theme);
    root.draw();

    assert(root.style == style);

}

@("Themes respect inheritance")
unittest {

    auto myTheme = nullTheme.derive(
        rule!Node(
            Rule.margin.sideX = 8,
        ),
        rule!Label(
            Rule.margin.sideTop = 6,
        ),
        rule!Button(
            Rule.margin.sideBottom = 4,
        ),
    );

    auto style = Style.init;
    myTheme.apply(button("", delegate { }), style);

    assert(style.margin == [8, 8, 6, 4]);

}

@("Rules can set properties dynamically")
unittest {

    auto myRule = rule!Label(
        Rule.textColor = color!"011",
        Rule.backgroundColor = color!"faf",
        (Label node) => node.isDisabled
            ? rule(Rule.tint = color!"000a")
            : rule()
    );

    auto myTheme = nullTheme.derive(
        rule!Label(
            myRule,
        ),
        rule!Button(
            myRule,
            Rule.textColor = color!"012",
        ),
    );

    auto style = Style.init;
    auto myLabel = label("");

    // Apply the style, including dynamic rules
    auto cbs = myTheme.apply(myLabel, style);
    assert(cbs.length == 1);
    cbs[0](myLabel).apply(myLabel, style);

    assert(style.textColor == color!"011");
    assert(style.backgroundColor == color!"faf");
    assert(style.tint == Style.init.tint);

    // Disable the node and apply again, it should change nothing
    myLabel.disable();
    myTheme.apply(myLabel, style);
    assert(style.tint == Style.init.tint);

    // Apply the callback, tint should change
    cbs[0](myLabel).apply(myLabel, style);
    assert(style.tint == color!"000a");

}

@("Rules using tags from different enums do not collide")
unittest {

    @NodeTag enum Foo { tag }
    @NodeTag enum Bar { tag }

    auto theme = nullTheme.derive(
        rule!Label(
            textColor = color("#f00"),
        ),
        rule!(Label, Foo.tag)(
            textColor = color("#0f0"),
        ),
    );

    Label fooLabel, barLabel;

    auto root = vspace(
        theme,
        fooLabel = label(.tags!(Foo.tag), "foo"),
        barLabel = label(.tags!(Bar.tag), "bar"),
    );

    root.draw();

    assert(fooLabel.pickStyle().textColor == color("#0f0"));
    assert(barLabel.pickStyle().textColor == color("#f00"));

}

@("Margins can be defined through methods, and combined")
unittest {

    import fluid.label;

    auto myLabel = label("");

    void testMargin(Rule rule, float[4] margin) {
        auto style = Style.init;
        rule.apply(myLabel, style);
        assert(style.margin == margin);
    }

    with (Rule) {

        testMargin(rule(margin = 2), [2, 2, 2, 2]);
        testMargin(rule(margin.sideX = 2), [2, 2, 0, 0]);
        testMargin(rule(margin.sideY = 2), [0, 0, 2, 2]);
        testMargin(rule(margin.sideTop = 2), [0, 0, 2, 0]);
        testMargin(rule(margin.sideBottom = 2), [0, 0, 0, 2]);
        testMargin(rule(margin.sideX = 2, margin.sideY = 4), [2, 2, 4, 4]);
        testMargin(rule(margin = [1, 2, 3, 4]), [1, 2, 3, 4]);
        testMargin(rule(margin.sideX = [1, 2]), [1, 2, 0, 0]);

    }

}

@("Rule.opacity can be used to change tint's alpha")
unittest {

    import std.math;

    auto myRule = rule(
        Rule.opacity = 0.5,
    );
    auto style = Style.init;

    myRule.apply(label(""), style);

    assert(style.opacity.isClose(127/255f));
    assert(style.tint == color!"ffffff7f");

    auto secondRule = rule(
        Rule.tint = color!"abc",
        Rule.opacity = 0.6,
    );

    style = Style.init;
    secondRule.apply(label(""), style);

    assert(style.opacity.isClose(153/255f));
    assert(style.tint == color!"abc9");

}

@("Rule copying tests class ancestry")
@trusted
unittest {

    import std.exception;
    import core.exception : AssertError;

    auto generalRule = rule(
        Rule.textColor = color!"#001",
    );
    auto buttonRule = rule!Button(
        Rule.backgroundColor = color!"#002",
        generalRule,
    );
    assertThrown!AssertError(
        rule!Label(buttonRule),
        "Label rule cannot inherit from a Button rule."
    );

    assertNotThrown(rule!Button(buttonRule));
    assertNotThrown(rule!Button(rule!Label()));

}

@("Dynamic rules cannot inherit from mismatched rules")
unittest {

    import fluid.space;
    import fluid.frame;

    auto theme = nullTheme.derive(
        rule!Space(
            (Space _) => rule!Frame(
                backgroundColor = color("#123"),
            ),
        ),
    );

    auto root = vspace(theme);
    root.draw();

    assert(root.pickStyle.backgroundColor == Color.init);

}

@("WhenRule immediately responds to changes")
unittest {

    import fluid.label;

    auto myTheme = Theme(
        rule!Label(
            Rule.textColor = color!"100",
            Rule.backgroundColor = color!"aaa",

            when!"a.isEmpty"(Rule.textColor = color!"200"),
            when!"a.text == `two`"(Rule.backgroundColor = color!"010")
                .otherwise(Rule.backgroundColor = color!"020"),
        ),
    );

    auto myLabel = label(myTheme, "one");
    myLabel.draw();

    assert(myLabel.pickStyle().textColor == color!"100");
    assert(myLabel.pickStyle().backgroundColor == color!"020");
    assert(myLabel.style.backgroundColor == color!"aaa");

    myLabel.text = "";

    assert(myLabel.pickStyle().textColor == color!"200");
    assert(myLabel.pickStyle().backgroundColor == color!"020");
    assert(myLabel.style.backgroundColor == color!"aaa");

    myLabel.text = "two";

    assert(myLabel.pickStyle().textColor == color!"100");
    assert(myLabel.pickStyle().backgroundColor == color!"010");
    assert(myLabel.style.backgroundColor == color!"aaa");

}

@("Basic children rules work")
unittest {

    import fluid.theme;
    import std.algorithm;

    auto theme = nullTheme.derive(

        // Labels are red by default
        rule!Label(
            textColor = color("#f00"),
        ),
        // Labels inside frames turn green
        rule!Frame(
            children!Label(
                textColor = color("#0f0"),
            ),
        ),

    );

    Label[2] greenLabels;
    Label[2] redLabels;

    auto root = vspace(
        theme,
        redLabels[0] = label("red"),
        vframe(
            greenLabels[0] = label("green"),
            hspace(
                greenLabels[1] = label("green"),
            ),
        ),
        redLabels[1] = label("red"),
    );

    root.draw();

    assert(redLabels[]  .all!(a => a.pickStyle.textColor == color("#f00")), "All red labels are red");
    assert(greenLabels[].all!(a => a.pickStyle.textColor == color("#0f0")), "All green labels are green");

}

@("Children rules can be nested")
unittest {

    import std.algorithm;

    auto theme = nullTheme.derive(

        // Labels are red by default
        rule!Label(
            textColor = color("#f00"),
        ),
        rule!Frame(
            // Labels inside frames turn blue
            children!Label(
                textColor = color("#00f"),
            ),
            // But if nested further, they turn green
            children!Frame(
                textColor = color("#000"),
                children!Label(
                    textColor = color("#0f0"),
                ),
            ),
        ),

    );

    Label[2] redLabels;
    Label[3] blueLabels;
    Label[4] greenLabels;

    auto root = vspace(
        theme,
        redLabels[0] = label("Red"),
        vframe(
            blueLabels[0] = label("Blue"),
            vframe(
                greenLabels[0] = label("Green"),
                vframe(
                    greenLabels[1] = label("Green"),
                ),
            ),
            blueLabels[1] = label("Blue"),
            vframe(
                greenLabels[2] = label("Green"),
            )
        ),
        vspace(
            vframe(
                blueLabels[2] = label("Blue"),
                vspace(
                    vframe(
                        greenLabels[3] = label("Green")
                    ),
                ),
            ),
            redLabels[1] = label("Red"),
        ),
    );

    root.draw();

    assert(redLabels[]  .all!(a => a.pickStyle.textColor == color("#f00")), "All red labels must be red");
    assert(blueLabels[] .all!(a => a.pickStyle.textColor == color("#00f")), "All blue labels must be blue");
    assert(greenLabels[].all!(a => a.pickStyle.textColor == color("#0f0")), "All green labels must be green");

}

@("`children` rules work inside of `when`")
unittest {

    auto theme = nullTheme.derive(
        rule!FrameButton(
            children!Label(
                textColor = color("#f00"),
            ),
            when!"a.isFocused"(
                children!Label(
                    textColor = color("#0f0"),
                ),
            ),
        ),
    );

    FrameButton first, second;
    Label firstLabel, secondLabel;

    auto root = vframe(
        theme,
        first = vframeButton(
            firstLabel = label("Hello"),
            delegate { }
        ),
        second = vframeButton(
            secondLabel = label("Hello"),
            delegate { }
        ),
    );

    root.draw();

    assert(firstLabel.pickStyle.textColor == color("#f00"));
    assert(secondLabel.pickStyle.textColor == color("#f00"));

    first.focus();
    root.draw();

    assert(firstLabel.pickStyle.textColor == color("#0f0"));
    assert(secondLabel.pickStyle.textColor == color("#f00"));

    second.focus();
    root.draw();

    assert(firstLabel.pickStyle.textColor == color("#f00"));
    assert(secondLabel.pickStyle.textColor == color("#0f0"));

}

@("`children` rules work inside of delegates")
unittest {

    // Note: This is impractical; in reality this will allocate memory excessively.
    // This could be avoided by allocating all breadcrumbs on a stack.
    class ColorFrame : Frame {

        Color color;

        this(Color color, Node[] nodes...) {
            this.color = color;
            super(nodes);
        }

    }

    auto theme = nullTheme.derive(
        rule!Label(
            textColor = color("#000"),
        ),
        rule!ColorFrame(
            (ColorFrame a) => rule(
                children!Label(
                    textColor = a.color,
                )
            )
        ),
    );

    ColorFrame frame;
    Label target;
    Label sample;

    auto root = vframe(
        theme,
        frame = new ColorFrame(
            color("#00f"),
            target = label("Colorful label"),
        ),
        sample = label("Never affected"),
    );

    root.draw();

    assert(target.pickStyle.textColor == color("#00f"));
    assert(sample.pickStyle.textColor == color("#000"));

    frame.color = color("#0f0"),
    root.draw();

    assert(target.pickStyle.textColor == color("#0f0"));
    assert(sample.pickStyle.textColor == color("#000"));

}

@("Children rules can contain `when` clauses and delegates")
unittest {

    // Focused button turns red, or green if inside of a frame
    auto theme = nullTheme.derive(
        rule!Frame(
            children!Button(
                when!"a.isFocused"(
                    textColor = color("#0f0"),
                ),
                (Node b) => rule(
                    backgroundColor = color("#123"),
                ),
            ),
        ),
        rule!Button(
            textColor = color("#000"),
            backgroundColor = color("#000"),
            when!"a.isFocused"(
                textColor = color("#f00"),
            ),
        ),
    );

    Button greenButton;
    Button redButton;

    auto root = vspace(
        theme,
        vframe(
            greenButton = button("Green", delegate { }),
        ),
        redButton = button("Red", delegate { }),
    );

    root.draw();

    assert(greenButton.pickStyle.textColor == color("#000"));
    assert(greenButton.pickStyle.backgroundColor == color("#123"));
    assert(redButton.pickStyle.textColor == color("#000"));
    assert(redButton.pickStyle.backgroundColor == color("#000"));

    greenButton.focus();
    root.draw();

    assert(greenButton.isFocused);
    assert(greenButton.pickStyle.textColor == color("#0f0"));
    assert(greenButton.pickStyle.backgroundColor == color("#123"));
    assert(redButton.pickStyle.textColor == color("#000"));
    assert(redButton.pickStyle.backgroundColor == color("#000"));

    redButton.focus();
    root.draw();

    assert(greenButton.pickStyle.textColor == color("#000"));
    assert(greenButton.pickStyle.backgroundColor == color("#123"));
    assert(redButton.pickStyle.textColor == color("#f00"));
    assert(redButton.pickStyle.backgroundColor == color("#000"));

}

@("Rule.typeface can change typeface")
unittest {

    import fluid.typeface;

    auto typeface = new FreetypeTypeface;
    auto sample = Rule.typeface = typeface;

    assert(sample.name == "typeface");

    auto target = Style.defaultTypeface;
    assert(target !is typeface);
    sample.value.apply(target);

    assert(target is typeface);
    assert(typeface is typeface);

}

@("Plain Rule.margin assignment overrides the entire margin")
unittest {

    auto sampleField = Rule.margin = 4;
    assert(sampleField.name == "margin");

    float[4] field = [1, 1, 1, 1];
    sampleField.value.apply(field);

    assert(field == [4, 4, 4, 4]);

}

@("Rule.margin supports partial changes")
unittest {

    auto sampleField = Rule.margin.sideX = 8;
    assert(sampleField.name == "margin");

    float[4] field = [1, 1, 1, 1];
    sampleField.value.apply(field);

    assert(field == [8, 8, 1, 1]);

}
