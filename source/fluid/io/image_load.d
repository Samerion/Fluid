/// I/O system for loading image data.
module fluid.io.image_load;

import fluid.types;

import fluid.future.context;

@safe:

/// Interface for loading images in varying formats, like PNG or JPG, into raw `Image`.
interface ImageLoadIO : IO {

    /// Load an image from raw bytes.
    /// Params:
    ///     data = Byte data of the image file.
    /// Throws:
    ///     Any `Exception` if the file is not a valid image file, or it cannot be decoded
    ///     by this I/O system.
    /// Returns:
    ///     Loaded image.
    Image loadImage(const(ubyte)[] image);

}
