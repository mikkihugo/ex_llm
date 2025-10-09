pub mod chat;

use std::collections::HashMap;

use anyhow::Result;
use async_trait::async_trait;
pub use chat::*;
use serde_json::Value;

use crate::{
  dspy::{ConversationHistory, Message, MetaSignature, LM},
  dspy_data::{Example, Prediction},
};

#[async_trait]
pub trait Adapter: Send + Sync + 'static {
  fn format(&self, signature: &dyn MetaSignature, inputs: Example) -> ConversationHistory;
  fn parse_response(&self, signature: &dyn MetaSignature, response: Message) -> HashMap<String, Value>;
  async fn call(&self, lm: &mut LM, signature: &dyn MetaSignature, inputs: Example) -> Result<Prediction>;
}
