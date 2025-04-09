module io_upgrade;

import fluid;
import fluid.future.context;

@safe:

interface SystemV1 : IO {

}

interface SystemV2 : SystemV1 {

}

alias systemV1Chain = nodeBuilder!SystemV1Chain;

class SystemV1Chain : NodeChain, SystemV1 {

    mixin controlIO;

    this(Node next = null) {
        super(next);
    }

    override void beforeResize(Vector2) {
        startIO();
    }

    override void afterResize(Vector2) {
        stopIO();
    }

}

alias systemV2Chain = nodeBuilder!SystemV2Chain;

class SystemV2Chain : NodeChain, SystemV2 {

    mixin controlIO;

    this(Node next = null) {
        super(next);
    }

    override void beforeResize(Vector2) {
        startIO();
    }

    override void afterResize(Vector2) {
        stopIO();
    }

}

alias systemUser = nodeBuilder!SystemUser;

class SystemUser : Node {

    SystemV1 systemV1;
    SystemV2 systemV2;

    int v;

    override void resizeImpl(Vector2) {
        use(systemV1).upgrade(systemV2);
        minSize = Vector2();

        if (systemV2) {
            v = 2;
        }
        else if (systemV1) {
            v = 1;
        }
        else {
            v = 0;
        }

        static assert(__traits(compiles, {
            use(systemV1).upgrade(systemV2);
        }));
        static assert(!__traits(compiles, {
            use(systemV2).upgrade(systemV1);
        }));
    }

    override void drawImpl(Rectangle, Rectangle) { }

}

@("The last loaded version of a chain is used if possible")
unittest {

    SystemUser[3] first, second;

    auto root = testSpace(
        first[0] = systemUser(),
        systemV2Chain(
            vspace(
                first[2] = systemUser(),
                systemV1Chain(
                    vspace(
                        first[1] = systemUser(),
                        second[1] = systemUser(),
                    ),
                ),
                second[2] = systemUser(),
            ),
        ),
        second[0] = systemUser(),
    );
    root.draw();

    assert(first[0].v == 0);
    assert(first[1].v == 1);
    assert(first[2].v == 2);

    assert(second[0].v == 0);
    assert(second[1].v == 1);
    assert(second[2].v == 2);

}
