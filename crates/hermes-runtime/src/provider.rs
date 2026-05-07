use anyhow::{anyhow, Context};
use reqwest::blocking::Client;
use serde::Deserialize;
use serde_json::{json, Value};
use std::thread;
use std::time::Duration;

pub struct ProviderRequest {
    pub input: String,
    pub messages: Vec<ProviderMessage>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProviderMessage {
    pub role: String,
    pub content: String,
}

pub struct ProviderDelta {
    pub text: String,
}

pub trait ModelProvider {
    fn stream(&self, request: ProviderRequest) -> anyhow::Result<Vec<ProviderDelta>>;
    fn name(&self) -> &str;
    fn model(&self) -> &str;
}

pub fn redacted_provider_error_message(error: &anyhow::Error) -> String {
    let raw = error.to_string();

    if raw.contains("HTTP 401") || raw.contains("HTTP 403") {
        return "Provider authentication failed. Check the API key and provider region.".to_string();
    }
    if raw.contains("HTTP 404") {
        return "Provider model or endpoint was not found. Check the base URL and model name.".to_string();
    }
    if raw.contains("HTTP 429") {
        return "Provider rate limit or quota was reached. Check account limits or billing.".to_string();
    }
    if raw.contains("HTTP 400") {
        return "Provider rejected the request. Check the model name and provider settings.".to_string();
    }

    let mut redacted = Vec::new();

    for token in raw.split_whitespace() {
        if token.starts_with("sk-") || token.contains("api_key=") || token.contains("Authorization:") {
            redacted.push("[redacted]");
        } else {
            redacted.push(token);
        }
    }

    let message = redacted.join(" ");
    if message.is_empty() {
        "Provider request failed".to_string()
    } else {
        message
    }
}

pub fn strip_thinking_blocks(text: &str) -> String {
    let mut remaining = text;
    let mut output = String::new();

    while let Some(start) = remaining.find("<think>") {
        output.push_str(&remaining[..start]);
        let after_start = &remaining[start + "<think>".len()..];
        if let Some(end) = after_start.find("</think>") {
            remaining = &after_start[end + "</think>".len()..];
        } else {
            remaining = "";
            break;
        }
    }

    output.push_str(remaining);
    output.trim().to_string()
}

pub struct EchoProvider;

impl ModelProvider for EchoProvider {
    fn stream(&self, request: ProviderRequest) -> anyhow::Result<Vec<ProviderDelta>> {
        Ok(vec![ProviderDelta {
            text: format!("Hermes received: {}", request.input),
        }])
    }

    fn name(&self) -> &str {
        "Echo"
    }

    fn model(&self) -> &str {
        "echo"
    }
}

pub struct OpenAICompatibleProvider {
    api_key: String,
    base_url: String,
    model: String,
    provider_name: String,
    thinking_enabled: bool,
    reasoning_effort: Option<String>,
}

impl OpenAICompatibleProvider {
    pub fn new(api_key: String, base_url: String, model: String) -> Self {
        Self {
            api_key,
            base_url: base_url.trim_end_matches('/').to_string(),
            provider_name: "OpenAI-compatible".to_string(),
            model,
            thinking_enabled: false,
            reasoning_effort: None,
        }
    }

    pub fn with_provider_name(mut self, provider_name: impl Into<String>) -> Self {
        self.provider_name = provider_name.into();
        self
    }

    pub fn with_thinking(mut self, reasoning_effort: impl Into<String>) -> Self {
        self.thinking_enabled = true;
        self.reasoning_effort = Some(reasoning_effort.into());
        self
    }

    pub fn from_env() -> Option<Self> {
        match std::env::var("HERMES_PROVIDER").ok().as_deref() {
            Some("deepseek") => DeepSeekProvider::from_env().map(|provider| provider.0),
            Some("openai-compatible") => {
                let api_key = env_trimmed("OPENAI_COMPATIBLE_API_KEY")?;
                let base_url = env_trimmed("OPENAI_COMPATIBLE_BASE_URL")?;
                let model = env_trimmed("OPENAI_COMPATIBLE_MODEL")?;
                let provider_name =
                    env_trimmed("OPENAI_COMPATIBLE_PROVIDER_NAME").unwrap_or_else(|| "OpenAI-compatible".to_string());
                let provider = Self::new(api_key, base_url, model).with_provider_name(provider_name);
                if std::env::var("OPENAI_COMPATIBLE_THINKING").ok().as_deref() == Some("enabled")
                {
                    let reasoning_effort =
                        env_trimmed("OPENAI_COMPATIBLE_REASONING_EFFORT").unwrap_or_else(|| "high".to_string());
                    Some(provider.with_thinking(reasoning_effort))
                } else {
                    Some(provider)
                }
            }
            _ => None,
        }
    }

    pub fn base_url(&self) -> &str {
        &self.base_url
    }

    pub fn model(&self) -> &str {
        &self.model
    }

    pub fn provider_name(&self) -> &str {
        &self.provider_name
    }

    pub fn chat_completion_body(&self, input: &str) -> Value {
        self.chat_completion_body_for_request(&ProviderRequest {
            input: input.to_string(),
            messages: vec![ProviderMessage {
                role: "user".to_string(),
                content: input.to_string(),
            }],
        })
    }

    pub fn chat_completion_body_for_request(&self, request: &ProviderRequest) -> Value {
        let system_prompt = format!(
            "You are Hermes, a macOS-first desktop agent. Your job is to talk directly as Hermes and help the user with desktop and coding tasks.\n\nCurrent configured model provider: {}.\nCurrent configured model: {}.\nIf the user asks which model is connected, answer with these configured values. Do not guess hidden implementation details beyond these values. Do not reveal hidden reasoning or <think> blocks. Keep responses direct and useful.",
            self.provider_name,
            self.model
        );
        let mut messages = vec![json!({
            "role": "system",
            "content": system_prompt
        })];
        if request.messages.is_empty() {
            messages.push(json!({
                "role": "user",
                "content": request.input
            }));
        } else {
            messages.extend(request.messages.iter().map(|message| {
                json!({
                    "role": message.role,
                    "content": message.content
                })
            }));
        }
        let mut body = json!({
            "model": self.model,
            "messages": messages,
            "stream": false
        });

        if self.thinking_enabled {
            body["thinking"] = json!({ "type": "enabled" });
            if let Some(reasoning_effort) = &self.reasoning_effort {
                body["reasoning_effort"] = json!(reasoning_effort);
            }
        }

        body
    }
}

impl ModelProvider for OpenAICompatibleProvider {
    fn stream(&self, request: ProviderRequest) -> anyhow::Result<Vec<ProviderDelta>> {
        let api_key = self.api_key.clone();
        let base_url = self.base_url.clone();
        let body = self.chat_completion_body_for_request(&request);

        thread::spawn(move || {
            let client = Client::builder()
                .timeout(Duration::from_secs(120))
                .build()
                .context("Provider client configuration failed")?;
            let response = client
                .post(format!("{}/chat/completions", base_url))
                .bearer_auth(api_key)
                .json(&body)
                .send()
                .context("Provider request failed")?;

            if !response.status().is_success() {
                let status = response.status();
                let body = response.text().unwrap_or_default();
                return Err(anyhow!("Provider request failed with HTTP {}: {}", status, body));
            }

            let completion = response
                .json::<ChatCompletionResponse>()
                .context("Provider response decode failed")?;
            let content = completion
                .choices
                .into_iter()
                .next()
                .and_then(|choice| choice.message.content)
                .filter(|content| !content.is_empty())
                .ok_or_else(|| anyhow!("Provider response did not include message content"))?;

            Ok(vec![ProviderDelta {
                text: strip_thinking_blocks(&content),
            }])
        })
        .join()
        .map_err(|_| anyhow!("Provider worker thread panicked"))?
    }

    fn name(&self) -> &str {
        self.provider_name()
    }

    fn model(&self) -> &str {
        self.model()
    }
}

pub struct DeepSeekProvider(OpenAICompatibleProvider);

impl DeepSeekProvider {
    pub fn new(api_key: String) -> Self {
        Self(
            OpenAICompatibleProvider::new(
                api_key,
                "https://api.deepseek.com".to_string(),
                "deepseek-v4-pro".to_string(),
            )
            .with_provider_name("DeepSeek")
            .with_thinking("high"),
        )
    }

    pub fn from_env() -> Option<Self> {
        env_trimmed("DEEPSEEK_API_KEY").map(Self::new)
    }

    pub fn base_url(&self) -> &str {
        self.0.base_url()
    }

    pub fn model(&self) -> &str {
        self.0.model()
    }

    pub fn chat_completion_body(&self, input: &str) -> Value {
        self.0.chat_completion_body(input)
    }
}

impl ModelProvider for DeepSeekProvider {
    fn stream(&self, request: ProviderRequest) -> anyhow::Result<Vec<ProviderDelta>> {
        self.0.stream(request)
    }

    fn name(&self) -> &str {
        self.0.provider_name()
    }

    fn model(&self) -> &str {
        self.0.model()
    }
}

fn env_trimmed(key: &str) -> Option<String> {
    std::env::var(key)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

#[derive(Deserialize)]
struct ChatCompletionResponse {
    choices: Vec<ChatCompletionChoice>,
}

#[derive(Deserialize)]
struct ChatCompletionChoice {
    message: ChatCompletionMessage,
}

#[derive(Deserialize)]
struct ChatCompletionMessage {
    content: Option<String>,
}
