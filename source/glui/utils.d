module glui.utils;

/// Change a property in place.
T set(string key, T : Object, V)(T node, V value) {

    mixin("node." ~ key) = value;
    return node;

}
