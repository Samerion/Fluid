/// I/O system for loading and writing files.
module fluid.io.file;

import fluid.types;

import fluid.future.context;

@safe:

/// Interface for loading and saving files from/to the file system.
///
/// A File I/O implementation is not restricted to the OS' file system API (the "regular" file system, like disks
/// directly connected to the computer and exposed to the app). An implementation is free to implement other means
/// of accessing files like downloading them off the web.
interface FileIO : IO {

    /// Load a file by its path in the filesystem.
    /// Params:
    ///     filename = Path of the file in the system.
    /// Throws:
    ///     Any `Exception` if the file doesn't exist or couldn't be loaded for any other reason.
    /// Returns:
    ///     Full contents of the file.
    ubyte[] loadFile(string filename);

    /// Write a file to the filesystem.
    /// Params:
    ///     filename = Path of the file in the filesystem.
    ///     content  = Content of the file.
    /// Throws:
    ///     Any `Exception` if the file couldn't be written.
    void writeFile(string filename, const(ubyte)[] content);

}

