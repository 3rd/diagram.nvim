# diagram.nvim

A Neovim plugin for rendering diagrams, powered by [image.nvim](https://github.com/3rd/image.nvim).
\
You'll **need to set up [image.nvim](https://github.com/3rd/image.nvim)** to use this plugin.

https://github.com/user-attachments/assets/cc71c122-3672-4bc6-b6fe-2ac36e36a78c

## Installation

With **lazy.nvim**:

```lua
{
  "3rd/diagram.nvim",
  dependencies = {
    "3rd/image.nvim",
  },
  opts = { -- you can just pass {}, defaults below
    integrations = {
      require("diagram.integrations.markdown"),
    },
  },
},
```
