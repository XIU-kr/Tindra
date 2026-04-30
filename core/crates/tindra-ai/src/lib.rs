// SPDX-License-Identifier: Apache-2.0
//
// tindra-ai — LLM provider abstraction (BYOK).
// Providers: Anthropic, OpenAI, local Ollama. Each pluggable via a `Provider`
// trait. Shell context (last N OSC-133-delimited prompt blocks) is captured
// from tindra-term and passed in as message context.
