module legacy.radiobox;

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
