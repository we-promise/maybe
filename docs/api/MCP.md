# Model Context Protocol (MCP)

This application ships with [fast-mcp](https://github.com/yjacquin/fast-mcp), a Ruby implementation of the Model Context Protocol. The middleware is mounted at `/mcp` and exposes two endpoints:

- `POST /mcp/messages` – JSON‑RPC endpoint for MCP requests
- `GET  /mcp/sse` – Server‑sent events stream

## Defining tools and resources

Add tools under `app/tools/` and resources under `app/resources/`. Tools inherit from `ApplicationTool` and resources from `ApplicationResource`.

Any subclasses of these base classes are automatically registered with the MCP server on boot.

## Example request

Once the Rails server is running, an MCP client can send a JSON‑RPC message to invoke a tool:

```bash
curl -X POST http://localhost:3000/mcp/messages \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":"1","method":"tools/execute","params":{"name":"your_tool","arguments":{}}}'
```

Replace `your_tool` with the name of a tool you defined.

Use the SSE endpoint to subscribe to resource updates or other MCP events:

```bash
curl http://localhost:3000/mcp/sse
```

Consult the [fast-mcp documentation](https://github.com/yjacquin/fast-mcp) for full protocol details.
