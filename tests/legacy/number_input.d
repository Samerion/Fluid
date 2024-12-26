@Migrated
module legacy.number_input;

import fluid;
import legacy;

import std.algorithm;

@safe:

@("NumberInput supports scientific notation")
@Migrated
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

