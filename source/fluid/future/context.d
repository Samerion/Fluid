module fluid.future.context;

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
    private Stack!IO[IOID] stacks;

    /// Returns: The active instance of the given IO interface.
    /// Params:
    ///     id = ID of the IO interface to load.
    IO get(IOID id) {

        auto stack = stacks.get(id, Stack!IO.init);

        if (stack.empty) {
            return null;
        }
        else {
            return stack.top;
        }

    }

    /// ditto
    T get(T)() {

        const id = ioID!T;
        return cast(T) get(id);

    }

    /// Push an IO instance onto the stack.
    /// Params:
    ///     id       = ID of the IO interface the instance implements.
    ///     instance = Instance to push.
    void push(IOID id, IO instance) {

        stacks.require(id, Stack!IO.init) ~= instance;

    }

    /// Remove the last entry on the stack.
    /// Params:
    ///     id = ID of the instance to remove.
    void pop(IOID id) {

        stacks[id].pop();

    }

}

enum isIO(T) = is(T == interface) 
    && is(T : IO)
    && !is(T == IO);

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
