#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Risk {
    ReadOnly,
    WritesFiles,
    ExecutesCommand,
    NetworkSideEffect,
}

pub fn requires_approval(risk: &Risk) -> bool {
    matches!(
        risk,
        Risk::WritesFiles | Risk::ExecutesCommand | Risk::NetworkSideEffect
    )
}
