// SPDX-License-Identifier: Apache-2.0
//
// tindra-mcp — Model Context Protocol.
// Server side exposes Tindra-as-a-tool to MCP clients (Claude Desktop, Cursor, ...):
//   - run_command(profile_id, cmd)   (gated; default off)
//   - read_screen(session_id)        (gated; default read-only on)
//   - list_profiles()                (gated; default off)
// Client side lets Tindra's AI assistant call external MCP servers.
// Transports: stdio, SSE, WebSocket — abstracted to weather spec churn.
