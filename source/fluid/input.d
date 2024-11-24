///
deprecated("`fluid.input` has been split into `fluid.input_node`, `fluid.io` and `fluid.tree`. "
    ~ "If you use `InputNode`, update the reference to `fluid.input_node`. "
    ~ "`fluid.input` will be removed in Fluid 0.9.0.")
module fluid.input;

public import fluid.io;
public import fluid.input_node;
public import fluid.tree.input_action;
public import fluid.tree.input_mapping;
