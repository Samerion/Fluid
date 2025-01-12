module nodes.preference_chain;

import core.time;

import fluid;

@safe:

alias preferenceTracker = nodeBuilder!PreferenceTracker;

class PreferenceTracker : Node {

    PreferenceIO preferenceIO;
    Duration doubleClickInterval;

    override void resizeImpl(Vector2) {
        require(preferenceIO);
    }

    override void drawImpl(Rectangle, Rectangle) {
        doubleClickInterval = preferenceIO.doubleClickInterval;
    }

}

@("PreferenceChain provides a double click interval")
unittest {

    auto preference = preferenceChain();
    auto tracker = preferenceTracker();
    auto root = chain(preference, tracker);

    root.draw();
    assert(tracker.doubleClickInterval != Duration.init);

}
