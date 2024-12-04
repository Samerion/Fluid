/// This module enables allocating a runtime ID for symbols. This makes it possible to uniquely identify node tags,
/// input actions and I/O modules.
/// 
/// Use `staticID` to produce new static IDs.
module fluid.future.static_id;

import std.traits;

@safe:

/// This function will produce a unique ID associated with the given symbol by allocating a small piece 
/// of static memory. Its address will be then used as an ID.
///
/// Each symbol will be associated with its own, unique ID. The ID will be the same for every call with 
/// the same symbol.
///
/// Returns: A unique ID produced from the symbol.
StaticID staticID(alias symbol)() {

    align(1)
    static immutable bool _id;

    debug {
        return StaticID(
            cast(size_t) &_id,
            fullyQualifiedName!symbol,
        );
    }
    else {
        return StaticID(
            cast(size_t) &_id,
        );
    }

}

/// Unique ID generated from a symbol.
///
/// See `staticID` for generating static IDs.
struct StaticID {

    /// The ID.
    size_t id;

    /// Name of the symbol holding the ID.
    debug string name;

    /// Returns: True if the IDs are the same.
    bool opEquals(StaticID other) const {

        return id == other.id;

    }

    /// Returns: The ID, which by itself is a sufficient hash.
    size_t toHash() const {

        return id;

    }

}

@("staticIDs are unique at runtime")
unittest {

    enum One;
    enum Two;

    auto one = staticID!One;
    auto two = staticID!Two;

    assert(one == staticID!One);
    assert(two == staticID!Two);
    assert(one == one);
    assert(two == two);
    assert(one != two);

    alias SecondOne = One;
    alias SecondTwo = Two;

    assert(one == staticID!SecondOne);
    assert(two == staticID!SecondTwo);
    assert(one != staticID!SecondTwo);
    assert(two != staticID!SecondOne);

}

@("staticIDs are global across threads")
@system
unittest {

    import std.concurrency;

    enum One;
    enum Two;

    // IDs are global across threads
    auto t0 = staticID!One;

    spawn({

        ownerTid.send(staticID!One);

        spawn({
            ownerTid.send(staticID!One);
        });

        ownerTid.send(receiveOnly!StaticID);
        ownerTid.send(staticID!Two);

    });

    auto t1 = receiveOnly!StaticID;
    auto t2 = receiveOnly!StaticID;

    auto c0 = staticID!Two;
    auto c1 = receiveOnly!StaticID;

    assert(t0 == t1);
    assert(t1 == t2);

    assert(c0 != t0);
    assert(c1 != t1);
    assert(c0 != t1);
    assert(c1 != t0);

    assert(t0 == t1);

}
