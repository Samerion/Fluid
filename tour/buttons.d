module fluid.tour.buttons;

import std.range;

import fluid;
import fluid.tour;


@safe:


@(
    () => label("Buttons are the most basic node when it comes to user input. Pressing a button triggers an event, "
        ~ "and that's about the functionality of the button. Under the hood, buttons are labels — but they're modified "
        ~ "to react to user clicks."),
    () => label("To initialize a button, you need to pass a delegate to dictate the button's effect. Here's one that "
        ~ "does nothing:"),
)
Label buttonExample() {

    return button("Hello, World!", delegate { });

}

@(
    () => label("Naturally, user interfaces are made to react to user input and other events that happen in the "
        ~ "system. The interface needs to change to keep displayed information up to date. Glui nodes expose "
        ~ "properties that make them possible to change. So, we can make the button change its text when clicked."),
    () => label("Just note that to refer to the button within itself we need to declare it beforehand."),
)
Label mutableLabelExample() {

    import std.range : cycle;

    Button myButton;
    auto texts = cycle(["Hello!", "Bonjour!", "¡Hola!", "Здравствуйте!"]);

    // Create the button
    myButton = button(texts.front, delegate {

        // Switch to the next text when clicked
        texts.popFront;
        myButton.text = texts.front;

    });

    return myButton;

}

@(
    () => label("Let's try making this a bit more complex. Once we connect a few nodes, we need to retain access to "
        ~ "all the nodes we're interested. If we place a label in a frame, we still need to keep a reference to the "
        ~ "label if we intend to change it. Fortunately, we can assign variables while building the tree. This is "
        ~ "somewhat unconventional, since a typical user interface system would instead have you query nodes by ID, "
        ~ "but this is simpler and more flexible."),
)
Frame nestedLabelFirstExample() {

    Label myLabel;
    auto texts = cycle(["Hello!", "Bonjour!", "¡Hola!", "Здравствуйте!"]);

    return vframe(
        myLabel = label(texts.front),
        button("Change text", delegate {

            // Change text of the button when clicked
            texts.popFront;
            myLabel.text = texts.front;

        }),
    );

}

@system
void unsafeFunction() { }

@(
    () => label("Of course, we also have the choice to assign the label on the same line it was declared "
        ~ "on. The downside of that usage is that it is usually helpful to keep each component of the tree united "
        ~ "for easier analysis. However, it might be preferrable if the tree is becoming complex, so you need "
        ~ "to find the right balance."),

    () => label(.tags!(Tags.heading), "A note on @safe-ty"),
    () => label("D has a memory safety checker, which will help prevent memory errors at compile-time. Fluid is fully "
        ~ "opted into it, which means your delegates will be rejected if the compiler deems them unsafe!"),
    () => label("Most importantly, C functions like the ones provided by Raylib aren't tested for safety, so they're "
        ~ "marked as unsafe and cannot be used in Fluid delegates. If you need to, you'll have to tell the compiler "
        ~ "by making them @trusted."),
    () => label("Tip: Memory safety is controlled with three attributes, @system, @trusted and @safe. The first two "
        ~ "disable memory safety checks, while @safe enables them. Use @trusted to mark code which you 'trust' to be "
        ~ "safe, so you can call it from @safe code."),
    () => button("More information on D memory safety", delegate {
        openURL("https://dlang.org/spec/memory-safe-d.html");
    }),
)
void safetyCheckerExample() @system {

    // This button calls an unsafe function, so it'll be rejected.
    button("Oops.", delegate {

        /* unsafeFunction(); Won't work! */

    });

    // To make it work, you have to make it @trusted.
    button("Trusted button.", delegate () @trusted {

        unsafeFunction();

    });

}

@(
    () => label(.tags!(Tags.heading), "Editing layouts"),
    () => label("Frame contents can be changed at runtime by changing their 'children' property. The operation is a "
        ~ "bit more complex than updating labels, and you have to pay attention to this one if you intend to rearrange "
        ~ "frames this way."),
)
Frame mutableFrameExample() {

    import std.algorithm : bringToFront;

    Frame myFrame;

    return vframe(
        myFrame = hframe(
            label("Foo, "),
            label("Bar, "),
            label("Baz, "),
        ),
        button("Reorder nodes", delegate {

            // Move the last node to start
            bringToFront(
                myFrame.children[0..$-1],
                myFrame.children[$-1..$]
            );
            myFrame.updateSize();

        }),
    );

}

// TODO cover .layout?

@(
    () => label("Fluid frames provide full control over their contents, making it possible to use the power of D "
        ~ "libraries for the job. See, to move the nodes around in the example above, we use 'bringToFront' from "
        ~ "std.algorithm. As a downside to this, Fluid is not able to detect changes and resize ahead of time, like it "
        ~ "does with labels, so you must call 'updateSize()' on the frame for the changes to apply. Fluid will issue "
        ~ "an error at runtime if you don't do this, so be careful!"),
    () => label("Do not worry though, a lot of layout management can be made easier with helpers like nodeSlot, which "
        ~ "we'll cover later."),
)
void endExample() { }
