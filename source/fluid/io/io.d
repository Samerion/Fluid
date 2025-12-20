///
module fluid.io.io;

@safe:

import fluid.future.static_id;

enum isIO(T) = is(T == interface)
    && is(T : IO)
    && !is(T == IO);

/// Get all IOs implemented by the given type
alias allIOs(T) = Filter!(isIO, InterfacesTuple!T);

interface IO {

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
