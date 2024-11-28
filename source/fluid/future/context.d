module fluid.future.context;

import std.meta;
import std.traits;

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

    TreeIOContext io;

} 

/// Active context for I/O operations. 
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

interface IO {

}

IOID ioID(T)()
if (isIO!T) {

    return IOID(staticID!T);

}

/// ID for an I/O interface.
struct IOID {

    StaticID id;

}
