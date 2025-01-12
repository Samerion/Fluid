module tests.nodes.time_machine;

import core.time;

import fluid;

@safe:

alias timeTracker = nodeBuilder!TimeTracker;

class TimeTracker : Node {

    TimeIO timeIO;
    MonoTime lastFrame;
    Duration frameTime;

    override void resizeImpl(Vector2) {
        require(timeIO);
        lastFrame = timeIO.now();
    }

    override void drawImpl(Rectangle, Rectangle) {
        frameTime = timeIO.timeSince(lastFrame);
        lastFrame = timeIO.now();
    }

}

@("TimeMachine can manipulate TimeIO output")
unittest {

    auto machine = timeMachine();
    auto event1 = machine.now();
    machine += 5.seconds;

    auto event2 = machine.now();
    machine += 4.seconds;

    auto event3 = machine.now();

    assert(event2 == event1 + 5.seconds);
    assert(event3 == event1 + 9.seconds);
    assert(event3 == event2 + 4.seconds);

}

@("TimeMachine's output is readable by nodes")
unittest {

    auto machine = timeMachine();
    auto tracker = timeTracker();
    auto root = chain(machine, tracker);

    root.draw();
    machine += 5.seconds;
    root.draw();
    assert(tracker.frameTime == 5.seconds);

    machine += 16.msecs;
    root.draw();
    assert(tracker.frameTime == 16.msecs);

    machine += 4.msecs;
    machine += 5.msecs;
    root.draw();
    assert(tracker.frameTime == 9.msecs);

}
