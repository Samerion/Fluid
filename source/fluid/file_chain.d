///
module fluid.file_chain;

import std.file;

import fluid.node;
import fluid.types;
import fluid.utils;
import fluid.node_chain;

import fluid.io.file;

@safe:

alias fileChain = nodeBuilder!FileChain;

/// File I/O implementation based on `std.file`, facilitating the C standard library for file reading.
class FileChain : NodeChain, FileIO {

    mixin controlIO;

    this(Node node = null) {
        super(node);
    }

    override void beforeResize(Vector2) {
        startIO();
    }

    override void afterResize(Vector2) {
        stopIO();
    }

    override ubyte[] loadFile(string filename) @trusted {
        return cast(ubyte[]) read(filename);
    }

    override void writeFile(string filename, const(ubyte)[] content) {
        write(filename, content);
    }

}
