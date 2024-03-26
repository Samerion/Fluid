# Fluid dependency binaries

Fluid relies on Freetype to perform text rendering. Freetype is a C library and thus will not be built by DUB. This
directory provides raw, pre-built binaries of Freetype matching the version used by Fluid. Fluid will link against those
*by default*.

Moreover, to make the showcase easier to run, Raylib binaries are provided just as well.

Warning: Supplied Ubuntu libraries may not work on other distros, and will not work on older Ubuntu releases.
