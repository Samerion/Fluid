module nodes.radiobox;

import fluid;

@safe:

@("Radiobox cannot be unchecked")
unittest {

    auto group = new RadioboxGroup;
    auto root = radiobox(group);
    assert(!root.isChecked);

    root.runInputAction!(FluidInputAction.press);
    assert( root.isChecked);

    // Pressing again doesn't uncheck the radiobox
    root.runInputAction!(FluidInputAction.press);
    assert( root.isChecked);

}

@("Checkmarks in different radioboxes in the same group is mutually exclusive")
unittest {

    auto group = new RadioboxGroup;
    auto r1 = radiobox(group);
    auto r2 = radiobox(group);
    assert(!r1.isChecked);
    assert(!r2.isChecked);

    r1.runInputAction!(FluidInputAction.press);
    assert( r1.isChecked);
    assert(!r2.isChecked);

    // Pressing again has no effect
    r1.runInputAction!(FluidInputAction.press);
    assert( r1.isChecked);
    assert(!r2.isChecked);

    r2.runInputAction!(FluidInputAction.press);
    assert(!r1.isChecked);
    assert( r2.isChecked);

    r1.runInputAction!(FluidInputAction.press);
    assert( r1.isChecked);
    assert(!r2.isChecked);

}

@("Different radiobox groups do not affect each other")
unittest {

    auto a = new RadioboxGroup;
    auto a1 = radiobox(a);
    auto a2 = radiobox(a);
    auto b = new RadioboxGroup;
    auto b1 = radiobox(b);
    auto b2 = radiobox(b);
    assert(!a1.isChecked);
    assert(!a2.isChecked);
    assert(!b1.isChecked);
    assert(!b2.isChecked);

    a1.runInputAction!(FluidInputAction.press);
    assert( a1.isChecked);
    assert(!a2.isChecked);
    assert(!b1.isChecked);
    assert(!b2.isChecked);

    b2.runInputAction!(FluidInputAction.press);
    assert( a1.isChecked);
    assert(!a2.isChecked);
    assert(!b1.isChecked);
    assert( b2.isChecked);

    a2.runInputAction!(FluidInputAction.press);
    assert(!a1.isChecked);
    assert( a2.isChecked);
    assert(!b1.isChecked);
    assert( b2.isChecked);

}

@("Radiobox is represented with a circle")
unittest {

    auto theme = nullTheme.derive(
        rule!Radiobox(
            Rule.padding = 2,
            Rule.extra = new Radiobox.Extra(1, color("#555"), color("#5552")),
            when!"a.isChecked"(
                Rule.extra = new Radiobox.Extra(1, color("#555"), color("#000"))
            ),
        ),

    );
    auto input = radiobox(new RadioboxGroup);
    auto root = testSpace(theme, input);

    input.size = Vector2(16, 16);  // (20, 20) with padding
    root.drawAndAssert(
        input.drawsCircle()       .at(10, 10).ofRadius( 8).ofColor("#5552"),
        input.drawsCircleOutline().at(10, 10).ofRadius(10).ofColor("#555"),
    );

    input.select();
    root.drawAndAssert(
        input.drawsCircle()       .at(10, 10).ofRadius( 8).ofColor("#000"),
        input.drawsCircleOutline().at(10, 10).ofRadius(10).ofColor("#555"),
    );

}
