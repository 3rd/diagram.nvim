# diagram.nvim

A Neovim plugin for rendering diagrams, powered by [image.nvim](https://github.com/3rd/image.nvim).
\
You'll **need to set up [image.nvim](https://github.com/3rd/image.nvim)** to use this plugin, and either [Kitty](https://github.com/kovidgoyal/kitty) or [Überzug++](https://github.com/jstkdng/ueberzugpp).

<https://github.com/user-attachments/assets/67545056-e95d-4cbe-a077-d6707349946d>

### Integrations & renderers

The plugin has a generic design with pluggable **renderers** and **integrations**.
\
Renderers take source code as input and render it to an image, often by calling an external process.
\
Integrations read buffers, extract diagram code, and dispatch work to the renderers.

| Integration | Supported renderers                          |
| ----------- | ------------------------------------------- |
| `markdown`  | `mermaid`, `plantuml`, `d2`, `gnuplot`      |
| `neorg`     | `mermaid`, `plantuml`, `d2`, `gnuplot`      |

| Renderer   | Requirements                                      |
| ---------- | ------------------------------------------------- |
| `mermaid`  | [mmdc](https://github.com/mermaid-js/mermaid-cli) |
| `plantuml` | [plantuml](https://plantuml.com/download)         |
| `d2`       | [d2](https://d2lang.com/)                         |
| `gnuplot`  | [gnuplot](http://gnuplot.info/)                   |

### Installation

With **lazy.nvim**:

```lua
{
  "3rd/diagram.nvim",
  dependencies = {
    { "3rd/image.nvim", opts = {} }, -- you'd probably want to configure image.nvim manually instead of doing this
  },
  opts = { -- you can just pass {}, defaults below
    events = {
      render_buffer = { "InsertLeave", "BufWinEnter", "TextChanged" },
      clear_buffer = {"BufLeave"},
    },
    renderer_options = {
      mermaid = {
        background = nil, -- nil | "transparent" | "white" | "#hex"
        theme = nil, -- nil | "default" | "dark" | "forest" | "neutral"
        scale = 1, -- nil | 1 (default) | 2  | 3 | ...
        width = nil, -- nil | 800 | 400 | ...
        height = nil, -- nil | 600 | 300 | ...
        cli_args = nil, -- nil | { "--no-sandbox" } | { "-p", "/path/to/puppeteer" } | ...
      },
      plantuml = {
        charset = nil,
        cli_args = nil, -- nil | { "-Djava.awt.headless=true" } | ...
      },
      d2 = {
        theme_id = nil,
        dark_theme_id = nil,
        scale = nil,
        layout = nil,
        sketch = nil,
        cli_args = nil, -- nil | { "--pad", "0" } | ...
      },
      gnuplot = {
        size = nil, -- nil | "800,600" | ...
        font = nil, -- nil | "Arial,12" | ...
        theme = nil, -- nil | "light" | "dark" | custom theme string
        cli_args = nil, -- nil | { "-p" } | { "-c", "config.plt" } | ...
      },
    }
  },
},
```

### Custom CLI Arguments

You can pass custom command-line arguments to any renderer using the `cli_args` option.

**Common Use Cases:**

1. **Fixing mmdc sandboxing issues (Nix/AppImage):**
   ```lua
   renderer_options = {
     mermaid = {
       cli_args = { "--no-sandbox" },
     },
   }
   ```

2. **Custom d2 padding:**
   ```lua
   renderer_options = {
     d2 = {
       cli_args = { "--pad", "0" },
     },
   }
   ```

The `cli_args` are inserted immediately after the executable name and before any standard arguments.

### Usage

To use the plugin, you need to set up the integrations and renderers in your Neovim configuration. Here's an example:

```lua
require("diagram").setup({
  integrations = {
    require("diagram.integrations.markdown"),
    require("diagram.integrations.neorg"),
  },
  renderer_options = {
    mermaid = {
      theme = "forest",
    },
    plantuml = {
      charset = "utf-8",
    },
    d2 = {
      theme_id = 1,
    },
    gnuplot = {
      theme = "dark",
      size = "800,600",
    },
  },
})
```

### API

The plugin exposes the following API functions:

- `setup(opts)`: Sets up the plugin with the given options.
- `get_cache_dir()`: Returns the root cache directory.
- `show_diagram_hover()`: Shows the diagram at cursor in a new tab (for manual keybinding).

### Diagram Hover Feature

You can add a keymap to view diagrams in a dedicated tab. Place your cursor inside any diagram code block and press the mapped key to open the rendered diagram in a new tab.

**Important**: This keymap configuration is essential for manual diagram viewing, especially when you have automatic rendering disabled.

```lua
{
  "3rd/diagram.nvim",
  dependencies = {
    "3rd/image.nvim",
  },
  opts = {
    -- Disable automatic rendering for manual-only workflow
    events = {
      render_buffer = {}, -- Empty = no automatic rendering
      clear_buffer = { "BufLeave" },
    },
    renderer_options = {
      mermaid = {
        theme = "dark",
        scale = 2,
      },
    },
  },
  keys = {
    {
      "K", -- or any key you prefer
      function()
        require("diagram").show_diagram_hover()
      end,
      mode = "n",
      ft = { "markdown", "norg" }, -- Only in these filetypes
      desc = "Show diagram in new tab",
    },
  },
},
```

**Key Configuration Details:**
- `"K"` - The key to press (can be changed to any key like `"<leader>d"`, `"gd"`, etc.)
- `ft = { "markdown", "norg" }` - Only activates in markdown and neorg files
- The function calls `require("diagram").show_diagram_hover()` to display the diagram

**Features:**
- **Cursor detection**: Works when cursor is anywhere inside diagram code blocks
- **New tab display**: Opens diagram in a dedicated tab with proper image rendering
- **Multiple diagram types**: Supports mermaid, plantuml, d2, and gnuplot
- **Easy navigation**:
  - `q` or `Esc` to close the diagram tab
  - `o` to open the image with system viewer (Preview, etc.)
- **Async rendering**: Handles both cached and newly-rendered diagrams
