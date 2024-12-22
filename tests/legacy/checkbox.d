module legacy.checkbox;

import fluid;

@safe:

@("Pressing the checkbox toggles its state")
unittest {

    int changed;

    auto root = checkbox(delegate {
        changed++;
    });

    root.runInputAction!(FluidInputAction.press);

    assert(changed == 1);
    assert(root.isChecked);

    root.runInputAction!(FluidInputAction.press);

    assert(changed == 2);
    assert(!root.isChecked);

}
