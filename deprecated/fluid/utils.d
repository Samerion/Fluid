///
deprecated("`fluid.utils` has been split into `fluid.node` (node builder) and `fluid.types`. "
    ~ "Please update your references before Fluid 0.9.0")
module fluid.utils;

public import fluid.tree.types;
public import fluid.node : nodeBuilder, isNodeBuilder, NodeBuilder, 
    simpleConstructor, SimpleConstructor, isSimpleConstructor;
public import fluid.hyperlink : openURL;
