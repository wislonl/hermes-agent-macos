use hermes_runtime::provider::{EchoProvider, ModelProvider, ProviderRequest};

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
