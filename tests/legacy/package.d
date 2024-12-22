/// Legacy Fluid tests, based on the old backend infrastructure. These will be removed in 0.8.0, first replacing
/// each with a corresponding 0.8.0-compatible solution. See https://git.samerion.com/Samerion/Fluid/issues/148 
/// for extra info.
///
/// This module provides UDAs for marking legacy tests. If a test is not marked, it means it has yet to be migrated.
/// `@Migrated` should be used for after a test has been migrated, or `@Abandoned` if a test will not be preserved.
/// After all tests have been migrated, the test module should also be marked as such.
module legacy;

@safe:

/// Used to mark legacy tests that have been translated to the 0.8.0 I/O system.
enum Migrated;

/// Used to mark legacy tests that might not hold true in future releases.
enum Abandoned;
