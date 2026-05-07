use anyhow::anyhow;
use hermes_runtime::provider::{EchoProvider, ModelProvider, ProviderDelta, ProviderRequest};
use hermes_runtime::runtime::create_run;
use serde_json::json;

#[test]
fn echo_provider_streams_deterministic_delta() {
    let provider = EchoProvider;

    let deltas = provider
        .stream(ProviderRequest {
            input: "hello".to_string(),
        })
        .unwrap();

    assert_eq!(deltas.len(), 1);
    assert_eq!(deltas[0].text, "Hermes received: hello");
}

struct FailingProvider;

impl ModelProvider for FailingProvider {
    fn stream(&self, _request: ProviderRequest) -> anyhow::Result<Vec<ProviderDelta>> {
        Err(anyhow!("secret api_key=sk-test leaked"))
    }
}

#[test]
fn provider_failure_returns_redacted_runtime_error() {
    let result = create_run(
        json!({
            "input": {
                "text": "hello"
            }
        }),
        &FailingProvider,
    );
    let error = match result {
        Ok(_) => panic!("expected provider failure"),
        Err(error) => error,
    };

    assert_eq!(error.code, -32603);
    assert_eq!(error.message, "Provider stream failed");
    assert!(!error.message.contains("sk-test"));
}
