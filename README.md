# diagram.nvim

A Neovim plugin for rendering diagrams, powered by [image.nvim](https://github.com/3rd/image.nvim).
\
You'll **need to set up [image.nvim](https://github.com/3rd/image.nvim)** to use this plugin, and either [Kitty](https://github.com/kovidgoyal/kitty) or [Überzug++](https://github.com/jstkdng/ueberzugpp).

https://github.com/user-attachments/assets/cc71c122-3672-4bc6-b6fe-2ac36e36a78c

### Integrations & renderers

The plugin has a generic design with pluggable **renderers** and **integrations**.
\
Renderers take source code as input and render it to an image, often by calling an external process.
\
Integrations read buffers, extract diagram code, and dispatch work to the renderers.

| Integration | Supported renderers   |
| ----------- | --------------------- |
| `markdown`  | `mermaid`, `plantuml` |
| `neorg`     | `mermaid`, `plantuml` |

| Renderer   | Requirements                                      |
| ---------- | ------------------------------------------------- |
| `mermaid`  | [mmdc](https://github.com/mermaid-js/mermaid-cli) |
| `plantuml` | [plantuml](https://plantuml.com/download)         |

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
        scale = 1, -- nil | 1 (default) | 2  | 3 | ...
      },
      plantuml = {
        charset = nil,
      },
    }
  },
},
```
