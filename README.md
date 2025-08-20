# 🚀 Peta HTTP Client

A powerful HTTP client plugin for Neovim that works like Postman, allowing you to manage, execute, and test HTTP requests directly from your editor.

## ✨ Features

- 🎨 **Beautiful UI**: Floating window with clean design
- 💾 **Persistent Storage**: Requests saved between sessions
- 🔄 **Multiple HTTP Methods**: GET, POST, PUT, DELETE, PATCH support
- 📝 **Headers & Body**: Full support for custom headers and request bodies
- 📊 **Response Viewer**: Split window showing complete HTTP responses
- ⚡ **Fast Execution**: Uses system `curl` for reliable requests
- 🎹 **Keyboard Driven**: Navigate entirely with keyboard shortcuts

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "OtavioPompolini/peta",
  cmd = { "Peta", "PetaOpen", "PetaClose" },
  keys = {
    { "<leader>pe", desc = "Toggle Peta HTTP Client" },
  },
  config = function()
    require("peta").setup({})
  end,
}
