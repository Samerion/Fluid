module new_io.input_map_space;

import fluid;

@safe:

class ActionTester : InputNode!Node {

    mixin enableInputActions;

    int pressed;
    int submitted;
    int broken;

    bool disableBreaking;

    override void resizeImpl(Vector2 space) { }
    override void drawImpl(Rectangle, Rectangle) { }

    @(FluidInputAction.press)
    bool press() {
        pressed++;
        return true;
    }

    @(FluidInputAction.submit)
    bool submit() {
        submitted++;
        return true;
    }

    @(FluidInputAction.breakLine)
    bool breakLine() {

        if (disableBreaking) return false;

        broken++;
        return true;

    }
    
    bool runInputAction(immutable InputActionID actionID, bool isActive, int) {

        return super.runInputAction(actionID, isActive);

    }

}

alias actionTester = nodeBuilder!ActionTester;

@("InputMapSpace can trigger input events")
unittest {

    // Create bindings
    auto map = InputMapping();
    map.bindNew!(FluidInputAction.press)(KeyboardIO.codes.space);
    map.bindNew!(FluidInputAction.submit)(KeyboardIO.codes.leftControl, KeyboardIO.codes.enter);
    map.bindNew!(FluidInputAction.breakLine)(KeyboardIO.codes.enter);
    map.bindNew!(FluidInputAction.submit)(KeyboardIO.codes.enter);

    auto tester = actionTester();
    auto root = inputMapSpace(map, tester);

    root.draw();
    assert(tester.pressed == 0);

    // Press the button using an event
    root.emitEvent(
        KeyboardIO.createEvent(KeyboardIO.Key.space, true),
        0,
        &tester.runInputAction,
    );
    root.draw();
    assert(tester.pressed == 1);

    // Break line
    root.emitEvent(
        KeyboardIO.createEvent(KeyboardIO.Key.enter, true),
        0,
        &tester.runInputAction,
    );
    root.draw();
    assert(tester.pressed   == 1);
    assert(tester.broken    == 1);
    assert(tester.submitted == 0, "Enter doesn't submit as breakLine takes priority");

    // Submit
    tester.disableBreaking = true;
    root.emitEvent(
        KeyboardIO.createEvent(KeyboardIO.Key.enter, true),
        0,
        &tester.runInputAction,
    );
    root.draw();
    assert(tester.pressed   == 1);
    assert(tester.broken    == 1);
    assert(tester.submitted == 1);

}
