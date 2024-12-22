module legacy.password_input;

import fluid;

@safe:

@("PasswordInput.shred fills data with invalid characters")
unittest {

    auto root = passwordInput();
    root.value = "Hello, ";
    root.caretToEnd();
    root.push("World!");

    assert(root.value == "Hello, World!");

    auto value1 = root.value;
    root.shred();

    assert(root.value == "");
    assert(value1 == "Hello, \xFF\xFF\xFF\xFF\xFF\xFF");

    root.push("Hello, World!");
    root.runInputAction!(FluidInputAction.previousChar);

    auto value2 = root.value;
    root.chopWord();
    root.push("Fluid");

    auto value3 = root.value;

    assert(root.value == "Hello, Fluid!");
    assert(value2 == "Hello, World!");
    assert(value3 == "Hello, Fluid!");

    root.shred();

    assert(root.value == "");
    assert(value2 == "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF");
    assert(value3 == value2);

}

@("PasswordInput.shred clears edit history")
unittest {

    auto root = passwordInput();
    root.push("Hello, x");
    root.chop();
    root.push("World!");

    assert(root.value == "Hello, World!");

    root.undo();

    assert(root.value == "Hello, ");

    root.shred();

    assert(root.value == "");

    root.undo();

    assert(root.value == "");

    root.redo();
    root.redo();

    assert(root.value == "");

}

