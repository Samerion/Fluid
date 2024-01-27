# Fluid dependency binaries

Fluid relies on Freetype to perform text rendering. Freetype is a C library and thus will not be built by DUB. This
directory provides raw, pre-built static binaries of Freetype matching the version used by Fluid.

Fluid will link against those *by default*. There is no support for dynamic libraries at the moment.

Warning: Supplied Ubuntu libraries may not work on other distros, and will not work on older Ubuntu releases.
