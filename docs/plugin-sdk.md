# Plugin SDK

> **Status:** Stub. The WIT (WebAssembly Interface Types) ABI lands in Phase 6.

## Goals

- Plugins shouldn't tank the host process if they crash or hang.
- Plugins shouldn't be able to read terminal output unless granted.
- Plugins should be language-agnostic (any language that can produce a WASM component works).
- Distribution should be a single `.wasm` file plus a signed manifest.

## Why WASM components?

- Memory isolation by default.
- Capability-based: nothing the host doesn't explicitly bind is reachable.
- The component model gives us interface types, so plugins written in Rust/JS/Python can consume the same ABI.

## Sketch

```wit
package tindra:plugin@0.1.0;

interface terminal {
    read snapshot(session: u64) -> string;
    write input(session: u64, data: string);
    on prompt-completed(session: u64, command: string, exit-code: s32);
}

interface profiles {
    list-readonly() -> list<string>;
    /* mutating ops require profiles:write capability */
}

world tindra-plugin {
    import terminal;
    import profiles;
    export init: func();
    export name: func() -> string;
}
```

## Permission manifest

```json
{
  "name": "zsh-snippet",
  "version": "0.1.0",
  "publisher": "tindra-official",
  "capabilities": [
    "terminal:write",
    "profiles:read"
  ],
  "exports": ["init", "show-snippet-picker"]
}
```

(More to come.)
