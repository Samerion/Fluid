/// This module contains interfaces for drawing geometry on a canvas.
module fluid.io.canvas;

import fluid.backend;
import fluid.future.context;

@safe:

/// I/O interface for canvas drawing functionality.
///
/// The canvas should use a coordinate system where (0,0) is the top-left corner. Every increment of 1 is equivalent 
/// to the distance of 1/96th of an inch. Consequentially, (96, 96) is 1 inch down and 1 inch right from the top-left
/// corner of the canvas.
///
/// The canvas should allow all inputs and never throw. If there's a defined boundary, the canvas should crop all 
/// geometry to fit.
interface CanvasIO : IO {

    /// Set an area the shapes can be drawn in. Any shape drawn after this call will be cropped to fit the specified
    /// rectangle on the canvas.
    ///
    /// Calling this again will replace the old area. `resetCropArea` can be called to remove this area.
    ///
    /// Params:
    ///     area = Area on the canvas to restrict all subsequently drawn shapes to.
    void cropArea(Rectangle area) nothrow;

    /// If `cropArea` was called before, this will reset set area, disabling the effect.
    void resetCropArea() nothrow;

    /// Draw a triangle, consisting of 3 vertices with counter-clockwise winding.
    /// Params:
    ///     a = First of the three points to connect.
    ///     b = Second of the three points to connect.
    ///     c = Third of the three points to connect.
    ///     color = Color to fill the triangle with.
    void drawTriangle(Vector2 a, Vector2 b, Vector2 c, Color color) nothrow;

    /// Draw a circle.
    /// Params:
    ///     center = Position of the circle's center.
    ///     radius = Radius of the circle.
    ///     color  = Color to fill the circle with.
    void drawCircle(Vector2 center, float radius, Color color) nothrow;

    /// Draw a rectangle.
    /// Params:
    ///     rectangle = Rectangle to draw.
    ///     color     = Color to fill the rectangle with.
    void drawRectangle(Rectangle rectangle, Color color) nothrow;

}
