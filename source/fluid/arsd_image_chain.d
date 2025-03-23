/// This module provides an image loading implementation based on `arsd-official:image-files`, as available on DUB.
/// It will only be accessible if this package is loaded through DUB.
module fluid.arsd_image_chain;

version (Have_arsd_official_image_files):

import arsd.image;

import fluid.node;
import fluid.types;
import fluid.utils;
import fluid.node_chain;

import fluid.io.file;
import fluid.io.image_load;

@safe:

alias arsdImageChain = nodeBuilder!ARSDImageChain;

/// An implementation of the `ImageLoadIO` API based on the `arsd-official:image-files` package available on DUB.
class ARSDImageChain : NodeChain, ImageLoadIO {

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

    Image loadImage(const(ubyte)[] data) @trusted {
        return loadImageFromMemory(data).toFluid();
    }

}

/// Convert an ARSD image to a Fluid `Image`.
/// Params:
///     image = An ARSD instance of a `MemoryImage`.
/// Returns:
///     A Fluid `Image` struct.
Image toFluid(MemoryImage image) @trusted {
    auto trueColorImage = image.getAsTrueColorImage();
    return Image(
        cast(fluid.types.Color[]) trueColorImage.imageData.bytes,
        image.width,
        image.height
    );
}
