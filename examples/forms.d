module fluid.showcase.forms;

import fluid;
import fluid.showcase;


@safe:


@(
    () => label("Fluid comes with a number of useful nodes for taking input from the user. Aside from basics like "
        ~ "buttons, there are text boxes, checkboxes, sliders and others."),
    () => label("You can ask the user for some text using a textInput. Provide a callback if you want to do "
        ~ "something when the user finishes — by pressing the enter key."),
)
Space textExample() {

    Label nameLabel;
    TextInput input;

    return vspace(
        nameLabel = label("What's your name?"),
        input = textInput("Your name...", delegate {
            nameLabel.text = "Hi, " ~ input.value ~ "!";
        }),
    );

}

@(
    () => label("It's a good idea to label all inputs to make their purpose clear to the user. Besides placing "
        ~ "a label next to it, wrap them in a 'FieldSlot' so Fluid can associate them together."),
    () => label(`Note that while text inputs have a placeholder option like "Your name..." above, it's not `
        ~ `visible unless the input is empty. Adding both is good practice.`),
)
Space fieldExample() {

    return vspace(
        fieldSlot!vframe(
            label("Name:"),
            textInput("Your name..."),
        ),
        fieldSlot!vframe(
            label("Password:"),
            passwordInput("Your password..."),
        ),
        fieldSlot!vframe(
            label("Multiline input"),
            textInput(.multiline),
        ),
    );

}

@(
    () => label("'FieldSlot' might not have a noticeable effect at first, but don't disregard it as useless. "
        ~ "FieldSlot will expand the clickable area of the input to cover the label, making it easier for the "
        ~ "user to locate and understand your fields. This is especially important for smaller nodes, like "
        ~ "checkboxes. Try clicking the label text below:"),
)
Space checkboxExample() {

    return fieldSlot!hframe(
        checkbox(),
        label("I agree to the terms and conditions"),
    );

}

@(
    () => label(.tags!(Tags.warning), "Note: Make sure your fieldSlots only contain a single input node. Placing two "
        ~ "checkboxes or text inputs inside one might cause unexpected behavior."),
    () => label("Moreover, 'FieldSlot' might be used by external tools to analyze the content, and for example, "
        ~ "provide information for screen readers. Fluid doesn't come with such tools at the time of writing, "
        ~ "but such improvements that might be introduced in the future."),
)
void noExample() { }
