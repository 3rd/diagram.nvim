# diagram.nvim

A Neovim plugin for rendering diagrams, powered by [image.nvim](https://github.com/3rd/image.nvim).
\
You'll **need to set up [image.nvim](https://github.com/3rd/image.nvim)** to use this plugin.

https://github.com/user-attachments/assets/cc71c122-3672-4bc6-b6fe-2ac36e36a78c

### Integrations & renderers

The plugin has a generic design with pluggable **renderers** and **integrations**.
\
Renderers take source code as input and render it to an image, often by calling an external process.
\
Integrations read buffers, extract diagram code, and dispatch work to the renderers.

| Integration | Supported renderers |
| ----------- | ------------------- |
| `markdown`  | `mermaid`           |

| Renderer  | Requirements                                      |
| --------- | ------------------------------------------------- |
| `mermaid` | [mmdc](https://github.com/mermaid-js/mermaid-cli) |

### Installation

With **lazy.nvim**:

```lua
{
  "3rd/diagram.nvim",
  dependencies = {
    "3rd/image.nvim",
  },
  opts = { -- you can just pass {}, defaults below
    renderer_options = {
      mermaid = {
        background = nil, -- nil | "transparent" | "white" | "#hex"
        theme = nil, -- nil | "default" | "dark" | "forest" | "neutral"
      },
    },
    integrations = {
      require("diagram.integrations.markdown"),
    },
  },
},
```
