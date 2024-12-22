module legacy.number_input;

import fluid;

import std.algorithm;

@safe:

@("[TODO] Legacy: NumberInput supports scientific notation")
unittest {

    import std.math;

    auto io = new HeadlessBackend;
    auto root = floatInput();

    root.io = io;

    io.inputCharacter("10e8");
    root.focus();
    root.draw();

    io.nextFrame;
    io.press(KeyboardKey.enter);
    root.draw();

    assert(root.value.isClose(10e8));
    assert(root.TextInput.value.among("1e+9", "1e+09"));

}

