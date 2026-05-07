use anyhow::anyhow;
use hermes_runtime::provider::{
    redacted_provider_error_message, strip_thinking_blocks, DeepSeekProvider, EchoProvider,
    ModelProvider, OpenAICompatibleProvider, ProviderDelta, ProviderMessage, ProviderRequest,
};
use hermes_runtime::runtime::create_run;
use serde_json::json;

#[test]
fn echo_provider_streams_deterministic_delta() {
    let provider = EchoProvider;

    let deltas = provider
        .stream(ProviderRequest {
            input: "hello".to_string(),
            messages: vec![],
        })
        .unwrap();

    assert_eq!(deltas.len(), 1);
    assert_eq!(deltas[0].text, "Hermes received: hello");
}

#[test]
fn deepseek_provider_uses_v4_pro_openai_compatible_defaults() {
    let provider = DeepSeekProvider::new("sk-test-secret".to_string());

    assert_eq!(provider.base_url(), "https://api.deepseek.com");
    assert_eq!(provider.model(), "deepseek-v4-pro");

    let body = provider.chat_completion_body("hello");
    assert_eq!(body["model"], "deepseek-v4-pro");
    assert_eq!(body["messages"][0]["role"], "system");
    assert_eq!(body["messages"][1]["role"], "user");
    assert_eq!(body["messages"][1]["content"], "hello");
    assert_eq!(body["thinking"]["type"], "enabled");
    assert_eq!(body["reasoning_effort"], "high");
    assert_eq!(body["stream"], false);
}

#[test]
fn openai_compatible_provider_uses_configured_base_url_and_model_without_thinking_by_default() {
    let provider = OpenAICompatibleProvider::new(
        "sk-test-secret".to_string(),
        "https://api.example.com/".to_string(),
        "example-model".to_string(),
    );

    assert_eq!(provider.base_url(), "https://api.example.com");
    assert_eq!(provider.model(), "example-model");

    let body = provider.chat_completion_body("hello");
    assert_eq!(body["model"], "example-model");
    assert!(body["messages"][0]["content"]
        .as_str()
        .unwrap()
        .contains("You are Hermes"));
    assert!(body["messages"][0]["content"]
        .as_str()
        .unwrap()
        .contains("example-model"));
    assert_eq!(body["messages"][1]["content"], "hello");
    assert!(body.get("thinking").is_none());
    assert!(body.get("reasoning_effort").is_none());
    assert_eq!(body["stream"], false);
}

#[test]
fn openai_compatible_provider_system_prompt_identifies_configured_provider() {
    let provider = OpenAICompatibleProvider::new(
        "sk-test-secret".to_string(),
        "https://api.example.com".to_string(),
        "MiniMax-M2.7-highspeed".to_string(),
    )
    .with_provider_name("MiniMax (China)");

    let body = provider.chat_completion_body("你用的是什么大模型");
    let system = body["messages"][0]["content"].as_str().unwrap();

    assert!(system.contains("MiniMax (China)"));
    assert!(system.contains("MiniMax-M2.7-highspeed"));
    assert!(!system.contains("Claude"));
    assert!(!system.contains("Anthropic"));
}

#[test]
fn strip_thinking_blocks_removes_model_reasoning_from_display_text() {
    let text = "<think>\ninternal reasoning\n</think>\n\n我是 Hermes。";

    assert_eq!(strip_thinking_blocks(text), "我是 Hermes。");
}

#[test]
fn openai_compatible_provider_can_enable_thinking_parameters() {
    let provider = OpenAICompatibleProvider::new(
        "sk-test-secret".to_string(),
        "https://api.example.com".to_string(),
        "example-model".to_string(),
    )
    .with_thinking("high");

    let body = provider.chat_completion_body("hello");

    assert_eq!(body["thinking"]["type"], "enabled");
    assert_eq!(body["reasoning_effort"], "high");
}

#[test]
fn provider_error_message_preserves_http_status_and_redacts_secrets() {
    let error = anyhow!(
        "Provider request failed with HTTP 500: {{\"error\":{{\"message\":\"bad key sk-secret-value\"}}}}"
    );

    let message = redacted_provider_error_message(&error);

    assert!(message.contains("HTTP 500"));
    assert!(message.contains("bad key"));
    assert!(!message.contains("sk-secret-value"));
    assert!(message.contains("[redacted]"));
}

#[test]
fn provider_error_message_summarizes_common_http_failures() {
    let unauthorized = anyhow!(
        "Provider request failed with HTTP 401 Unauthorized: {{\"error\":{{\"message\":\"bad key sk-secret-value\"}}}}"
    );
    let missing_model = anyhow!(
        "Provider request failed with HTTP 404 Not Found: {{\"error\":{{\"message\":\"model not found\"}}}}"
    );
    let rate_limited = anyhow!(
        "Provider request failed with HTTP 429 Too Many Requests: {{\"error\":{{\"message\":\"quota exceeded\"}}}}"
    );

    assert_eq!(
        redacted_provider_error_message(&unauthorized),
        "Provider authentication failed. Check the API key and provider region."
    );
    assert_eq!(
        redacted_provider_error_message(&missing_model),
        "Provider model or endpoint was not found. Check the base URL and model name."
    );
    assert_eq!(
        redacted_provider_error_message(&rate_limited),
        "Provider rate limit or quota was reached. Check account limits or billing."
    );
}

struct FailingProvider;

impl ModelProvider for FailingProvider {
    fn stream(&self, _request: ProviderRequest) -> anyhow::Result<Vec<ProviderDelta>> {
        Err(anyhow!("secret api_key=sk-test leaked"))
    }

    fn name(&self) -> &str {
        "Failing"
    }

    fn model(&self) -> &str {
        "failing-test"
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
    assert_eq!(error.message, "secret [redacted] leaked");
    assert!(!error.message.contains("sk-test"));
}

#[test]
fn openai_compatible_provider_sends_conversation_history_as_messages() {
    let provider = OpenAICompatibleProvider::new(
        "sk-test-secret".to_string(),
        "https://api.example.com".to_string(),
        "example-model".to_string(),
    );

    let body = provider.chat_completion_body_for_request(&ProviderRequest {
        input: "Follow up".to_string(),
        messages: vec![
            ProviderMessage {
                role: "assistant".to_string(),
                content: "Previous answer".to_string(),
            },
            ProviderMessage {
                role: "user".to_string(),
                content: "Follow up".to_string(),
            },
        ],
    });

    assert_eq!(body["messages"][0]["role"], "system");
    assert_eq!(body["messages"][1]["role"], "assistant");
    assert_eq!(body["messages"][1]["content"], "Previous answer");
    assert_eq!(body["messages"][2]["role"], "user");
    assert_eq!(body["messages"][2]["content"], "Follow up");
}
