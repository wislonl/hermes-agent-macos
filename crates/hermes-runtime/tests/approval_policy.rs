use hermes_runtime::approval::{requires_approval, Risk};

#[test]
fn read_only_operations_do_not_require_approval() {
    assert!(!requires_approval(&Risk::ReadOnly));
}

#[test]
fn shell_and_write_operations_require_approval() {
    assert!(requires_approval(&Risk::ExecutesCommand));
    assert!(requires_approval(&Risk::WritesFiles));
}
