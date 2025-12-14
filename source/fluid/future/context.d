module fluid.future.context;

import std.meta;
import std.traits;

import fluid.types;
import fluid.tree : TreeAction;
import fluid.future.static_id;

@safe:

/// This hook is called every time a new node tree is created to provide a tree wrapper, unless
/// one such wrapper was already provided.
static shared TreeWrapper delegate() @safe createDefaultTreeWrapper;

shared static this() {
    version (Have_raylib_d) {
        import fluid.raylib_view : raylibStack;
        createDefaultTreeWrapper = () => raylibStack.v5_5();
    }
    else version (Fluid_TestSpace) {
        import fluid.test_space : testWrapper;
        createDefaultTreeWrapper = () => testWrapper();
    }
    else static assert(false, "No default `TreeWrapper` is available. "
        ~ "Please assign `createDefaultTreeWrapper`.");
}

struct TreeContext {

    TreeContextData* ptr;

    alias ptr this;

    /// Create the context if it doesn't already exist.
    void prepare() {
        if (ptr is null) {
            ptr = new TreeContextData(
                createDefaultTreeWrapper());
        }
    }

    bool opCast(T : bool)() const {
        return ptr !is null;
    }

}

struct TreeContextData {

    import fluid.theme : Breadcrumbs;

    public {

        /// [TreeWrapper] instance this tree should use. This is a wrapper for [Node.draw],
        /// called to handle drawing the root node. May be null.
        ///
        /// It is the wrapper's responsibility to prepare core I/O systems like `CanvasIO` and
        /// `HoverIO` that will be used by the Fluid node tree during runtime. This enables Fluid
        /// to skip the burden of configuration from the programmer:
        ///
        /// ---
        /// auto root = label("Hello, World!");  // requires CanvasIO
        /// root.draw();  // Works out of the box
        /// ---
        ///
        /// If `null`, the wrapper will not be used, and the node tree will be drawn directly,
        /// with no prior setup.
        TreeWrapper wrapper;

        /// Keeps track of currently active I/O systems.
        TreeIOContext io;

        /// Manages and runs tree actions.
        TreeActionContext actions;

        /// Current breadcrumbs. These are assigned to any node that is resized or drawn at the
        /// time.
        ///
        /// Any node that introduces its own breadcrumbs will push onto this stack, and pop once
        /// finished.
        Breadcrumbs breadcrumbs;

    }

    private {
        int _lockTint;
        auto _tint = Color(0xff, 0xff, 0xff, 0xff);
    }

    /// Tint is a transitive styling property that can be used to reduce color intensity of everything
    /// that a node draws. Tint applies per channel, which means it can be used to reduce opacity (by changing
    /// the alpha channel) and any of the three RGB colors.
    ///
    /// A tint of value `0` sets intensity to 0% (disable). A tint of value `255` sets intensity to 100% (no change).
    ///
    /// See_Also:
    ///     `Style.tint`
    /// Returns: The current tint.
    Color tint() const nothrow {
        return _tint;
    }

    package (fluid)
    Color tint(Color newValue) nothrow {
        if (_lockTint > 0) {
            return _tint;
        }
        else {
            return _tint = newValue;
        }
    }

    /// Lock tint in place, preventing it from changing, or cancel a lock, making changes possible again.
    ///
    /// This function is needed for compatibility with the legacy `FluidBackend` system.
    /// Locks can be stacked, so if `lockTint()` is called twice, `unlockTint()` also has to be called twice
    /// to unlock tinting.
    ///
    /// It is expected that this function will be deprecated as soon as `FluidBackend` is no longer a part
    /// of Fluid. It will then be deleted in the next minor release.
    void lockTint() {
        _lockTint++;
    }

    /// ditto
    void unlockTint() {
        if (_lockTint > 0) {
            _lockTint--;
        }
    }

}

/// Active context for I/O operations. Keeps track of currently active systems for each I/O interface.
///
/// I/O systems are changed by a replace operation. `replace` takes the new I/O systems, but returns the one set
/// previously. This can be used to manage I/Os as a stack:
///
/// ---
/// auto previous = io.replace(id, this);
/// scope (exit) io.replace(id, previous);
/// ---
struct TreeIOContext {

    import std.range;
    import std.algorithm : completeSort;

    struct IOInstance {
        IOID id;
        IO io;
        int opCmp(const IOInstance rhs) const {
            return id.opCmp(rhs.id);
        }
        int opCmp(const IOID rhs) const {
            return id.opCmp(rhs);
        }
    }

    /// Key-value pairs of active I/O systems. Each pair contains the system and the ID of the interface
    /// it implements. Pairs are sorted by the interface ID.
    private SortedRange!(IOInstance[]) activeIOs;

    /// Returns:
    ///     The active instance of the given IO interface.
    ///     `null`, no instance of this interface is currently active.
    /// Params:
    ///     id = ID of the IO interface to load.
    IO get(IOID id) {

        auto range = activeIOs.equalRange(id);
        if (range.empty) {
            return null;
        }
        else {
            return range.front.io;
        }

    }

    /// ditto
    T get(T)() {

        const id = ioID!T;
        return cast(T) get(id);

    }

    /// Set currently active I/O instance for a set interface.
    /// Params:
    ///     id     = ID of the IO interface the instance implements.
    ///     system = System to activate.
    /// Returns:
    ///     Returns *previously set* I/O instance.
    IO replace(IOID id, IO system) {

        auto range = activeIOs.equalRange(id);
        auto instance = IOInstance(id, system);

        // Nothing set, add a new value
        if (range.empty) {
            IOInstance[1] instanceRange = instance;
            completeSort(activeIOs, instanceRange[]);
            activeIOs = assumeSorted(activeIOs.release ~ instanceRange[]);
            return null;
        }

        // Override the previous result
        else {
            auto previous = range.front;
            range.front = instance;
            return previous.io;
        }

    }

    /// Iterate on all active I/O systems.
    ///
    /// Elements are passed by value and cannot be modified.
    ///
    /// Returns:
    ///     A sorted input range of `(IOID id, IO io)` pairs.
    auto opIndex() {

        // `map` should prevent modifications
        import std.algorithm : map;

        return activeIOs.save.map!(a => a).assumeSorted;

    }

    /// Create a copy of the context.
    ///
    /// This creates a shallow clone: I/O systems can be replaced in the copy without affecting the original
    /// and vice-versa. The individual systems will *not* be copied.
    ///
    /// This is useful if the I/O stack created at some specific point in time has to be reproduced elsewhere.
    /// For example, in a drag-and-drop scenario, while a node is being dragged, it does not have a place as a child
    /// of any node. A copy of the I/O stack it had at the start is used to continue drawing while the node
    /// is "in air".
    ///
    /// Returns:
    ///     A shallow copy of the I/O context.
    TreeIOContext dup() {
        return TreeIOContext(activeIOs.release.dup.assumeSorted);
    }

}

enum isIO(T) = is(T == interface)
    && is(T : IO)
    && !is(T == IO);

/// Get all IOs implemented by the given type
alias allIOs(T) = Filter!(isIO, InterfacesTuple!T);

interface HasContext {

    /// Returns: The current tree context.
    inout(TreeContext) treeContext() inout nothrow;

}

interface IO : HasContext {

    bool opEquals(const Object) const;

    /// Load a resource by reference. This is the same as `Node.load`.
    /// Params:
    ///     resource = Resource to load. It will be updated with identifying information.
    void loadTo(this This, T)(ref T resource) {

        auto io = cast(This) this;

        // Load the resource
        const id = io.load(resource);

        // Pass data into the resource
        resource.load(io, id);

    }

    /// Load an upgrade to a newer version of this I/O system if one is available.
    ///
    /// To preserve backwards compatibility, when upgrading to a new version, you can keep loading
    /// old versions:
    ///
    /// ---
    /// ActionIOv1 actionIOv1;
    /// ActionIOv2 actionIOv2;
    /// override void resizeImpl(Vector2) {
    ///     use(actionIOv1).upgrade(actionIOv2);
    ///
    ///     if (actionIOv2) {
    ///         // v2 is available
    ///     }
    ///     else if (actionIOv1) {
    ///         // v1 is available
    ///     }
    ///     else {
    ///         // system unavailable
    ///     }
    /// }
    /// ---
    ///
    /// Using `upgrade` instead of just another `use` can help in situations where only some of
    /// the implementations have been updated:
    ///
    /// ---
    /// a = systemV2Chain(
    ///     systemUser(),  // uses a (v2)
    ///     b = systemV1Chain(
    ///         systemUser(),  // uses b (v1), even if v2 is available
    ///     )
    /// )
    /// ---
    ///
    /// Params:
    ///     newIO = Newer version of the system to upgrade to.
    ///         This is an out parameter; the variable will be assigned in place.
    /// Returns:
    ///     Instance of the newer system, if available.
    T upgrade(T, this This)()
    if (is(T : This))
    do {
        return cast(T) this;
    }

    /// ditto
    T upgrade(T, this This)(out T newIO)
    if (is(T : This))
    do {
        return newIO = upgrade!(T, This)();
    }

}

IOID ioID(T)()
if (isIO!T) {

    return IOID(staticID!T);

}

/// ID for an I/O interface.
struct IOID {

    StaticID id;

    int opCmp(const IOID rhs) const {
        return id.opCmp(rhs.id);
    }

}

/// Keeps track of currently active actions.
struct TreeActionContext {

    import std.array;

    private {

        struct RunningAction {

            TreeAction action;
            int generation;

            bool isStopped() const {
                return action.generation > generation;
            }

        }

        /// Currently running actions.
        Appender!(RunningAction[]) _actions;

        /// Number of running iterators. Removing tree actions will only happen if there is exactly one
        /// running iterator, as to not break the other ones.
        ///
        /// Multiple iterators may run in case a tree action draws nodes on its own: one iterator triggers
        /// the action, and the drawn node activates another iterator.
        int _runningIterators;

    }

    /// Start a number of tree actions. As the node tree is drawn, the action's hook will be called whenever
    /// a relevant place is reached in the tree.
    ///
    /// To stop a running action, call the action's `stop` method. Most tree actions will do it automatically
    /// as soon as their job is finished.
    ///
    /// If the action is already running, the previous run will be aborted. The action can only run once at a time.
    ///
    /// Params:
    ///     actions = Actions to spawn.
    void spawn(TreeAction[] actions...) {

        _actions.reserve(_actions[].length + actions.length);

        // Start every action and run the hook
        foreach (action; actions) {

            _actions ~= RunningAction(action, ++action.generation);
            action.started();


        }

    }

    /// List all currently active actions in a loop.
    int opApply(int delegate(TreeAction) @safe yield) {

        // Update the iterator counter
        _runningIterators++;
        scope (exit) _runningIterators--;

        bool kept;

        // Iterate on active actions
        // Do *not* increment if an action was removed
        for (size_t i = 0; i < _actions[].length; i += kept) {

            auto action = _actions[][i];
            kept = true;

            // If there's one running iterator, remove it from the array
            // Don't pass stopped actions to the iterator
            if (action.isStopped) {

                if (_runningIterators == 1) {
                    _actions[][i] = _actions[][$-1];
                    _actions.shrinkTo(_actions[].length - 1);
                    kept = false;
                }
                continue;

            }

            // Run the hook
            if (auto result = yield(action.action)) return result;

        }

        return 0;

    }

}

/// Prepares and draws the node tree. This wrapper sets up I/O systems needed for the node tree
/// before the tree is drawn.
interface TreeWrapper {
    import fluid.node;

    /// Draw the node tree.
    ///
    /// The wrapper is called every frame, and needs to attach relevant I/O systems, draw the
    /// given node, then detach again. Typically, the Wrapper does this by supplying its own stack
    /// of nodes, and wrapping the given node as a child.
    ///
    /// Params:
    ///     context = Active tree context.
    ///         The wrapper should assign this context to any node it draws, through
    ///         [Node.prepare].
    ///     root = Root node of the tree for the wrapper to draw.
    void drawTree(TreeContext context, Node root);

    ///
    @("drawTree implementation example")
    unittest {
        import fluid.hover_chain;

        class MyWrapper : TreeWrapper {
            HoverChain chain;

            this() {
                chain = hoverChain();
            }

            void drawTree(TreeContext context, Node root) {
                chain.next = root;
                chain.prepare(context);
                chain.drawAsRoot();
            }

        }
    }

}
