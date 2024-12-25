module nodes.file_chain;

import std.file;
import std.ascii : letters;
import std.conv : to;
import std.path : buildPath;
import std.random : randomSample;
import std.utf : byCodeUnit;

import fluid;

@safe:

alias temporaryFile = nodeBuilder!TemporaryFile;

class TemporaryFile : Node {

    FileIO fileIO;
    string filename;

    this() {
        this.filename = tempDir.buildPath("fluid_test_file" ~ letters.byCodeUnit.randomSample(20).to!string);
    }

    override void resizeImpl(Vector2) {
        require(fileIO);
        minSize = Vector2(0, 0);
    }

    override void drawImpl(Rectangle, Rectangle) {

    }

    ubyte[] load() {
        return fileIO.loadFile(filename);
    }
    void write(const(ubyte)[] content) {
        fileIO.writeFile(filename, content);
    }

}

@("File chain can write and load files")
unittest {

    auto file = temporaryFile();
    auto root = fileChain(file);
    root.draw();
    file.write(cast(const ubyte[]) "Hello, World!");

    assert(file.filename.readText == "Hello, World!");
    assert(file.load() == "Hello, World!");

}
