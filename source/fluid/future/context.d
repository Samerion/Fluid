module fluid.future.context;

import std.meta;
import std.traits;

import fluid.types;
import fluid.tree : TreeAction;
import fluid.future.stack;
import fluid.future.static_id;

@safe:

struct TreeContext {

    TreeContextData* ptr;

    alias ptr this;

    /// Create the context if it doesn't already exist.
    void prepare() {

        if (ptr is null) {
            ptr = new TreeContextData();
        }

    }

    bool opCast(T : bool)() const {

        return ptr !is null;

    }

}

struct TreeContextData {

    public {

        /// Keeps track of currently active I/O systems.
        TreeIOContext io;

        /// Manages and runs tree actions.
        TreeActionContext actions;

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
struct TreeIOContext {

    /// Map of I/O interface IDs to an index in the IO array.
    private IO[IOID] activeIOs;

    /// Returns: The active instance of the given IO interface.
    /// Params:
    ///     id = ID of the IO interface to load.
    IO get(IOID id) {

        return activeIOs.get(id, null);

    }

    /// ditto
    T get(T)() {

        const id = ioID!T;
        return cast(T) get(id);

    }

    /// Set currently active I/O instance for a set interface.
    /// Params:
    ///     id       = ID of the IO interface the instance implements.
    ///     instance = Instance to activate.
    /// Returns:
    ///     Returns *previously set* I/O instance.
    IO replace(IOID id, IO instance) {

        // Override the previous result
        if (auto result = id in activeIOs) {
            auto previous = *result;
            *result = instance;
            return previous;
        }

        // Nothing set, create a new value
        else {
            activeIOs[id] = instance;
            return null;
        }

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

}

IOID ioID(T)()
if (isIO!T) {

    return IOID(staticID!T);

}

/// ID for an I/O interface.
struct IOID {

    StaticID id;

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
