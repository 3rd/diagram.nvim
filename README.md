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
    "3rd/image.nvim",
  },
  opts = { -- you can just pass {}, defaults below
    renderer_options = {
      mermaid = {
        background = nil, -- nil | "transparent" | "white" | "#hex"
        theme = nil, -- nil | "default" | "dark" | "forest" | "neutral"
        scale = 1, -- nil | 1 (default) | 2  | 3 | ...
        width = nil, -- nil | 800 | 400 | ...
        height = nil, -- nil | 600 | 300 | ...
        pupperteer_path = "home/<user>/.config/puppeteer/puppeteer.config.json", --nil
      },
      plantuml = {
        charset = nil,
      },
      d2 = {
        theme_id = nil,
        dark_theme_id = nil,
        scale = nil,
        layout = nil,
        sketch = nil,
      },
      gnuplot = {
        size = nil, -- nil | "800,600" | ...
        font = nil, -- nil | "Arial,12" | ...
        theme = nil, -- nil | "light" | "dark" | custom theme string
      },
    }
  },
},
```
> [!info] 
> pupperteer_path should be the path to your puppeteer.config.json, set the correct path and user. 

#### puppeteer options
Puppeteer config file can be found in ~/.config/puppeteer/puppeteer.config.json and able to set chrome-headless-shell versión, required by mermaid-cli.
```json
{
  "executablePath": "/home/<user>/.cache/puppeteer/chrome-headless-shell/linux-132.0.6834.110/chrome-headless-shell-linux64/chrome-headless-shell",
  "puppeteer": {
    "chromiumRevision": "132.0.6834.110"
  }
}
```

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
