pub struct ProviderRequest {
    pub input: String,
}

pub struct ProviderDelta {
    pub text: String,
}

pub trait ModelProvider {
    fn stream(&self, request: ProviderRequest) -> anyhow::Result<Vec<ProviderDelta>>;
}

pub struct EchoProvider;

impl ModelProvider for EchoProvider {
    fn stream(&self, request: ProviderRequest) -> anyhow::Result<Vec<ProviderDelta>> {
        Ok(vec![ProviderDelta {
            text: format!("Hermes received: {}", request.input),
        }])
    }
}
