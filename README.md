Still working on this one.

# AI Assistant for Neovim

A deep integration of AI assistance into your Neovim workflow with project awareness, multiple AI providers, and advanced context management.

## Features

- **Multiple AI Provider Support**: OpenAI, Anthropic (Claude), Azure OpenAI, and Mistral
- **Project Context**: Smart project-aware context building for more relevant AI responses
- **Treesitter Integration**: Intelligent code understanding with syntax awareness
- **Intuitive UI**: Panel interface for seamless interaction with AI
- **Command API**: Comprehensive API for extending or integrating with other plugins
- **Telescope Integration**: Fuzzy finding for providers, history, and context files
- **Streaming Responses**: Real-time AI responses for a more interactive experience
- **Code Change Preview**: Preview and selectively apply code suggestions

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "anongecko/ai-assistant.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim",
    "nvim-treesitter/nvim-treesitter",
    "rcarriga/nvim-notify", -- optional
  },
  config = function()
    require("ai-assistant").setup({
      -- Optional configuration here
    })
  end,
}
```

With [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "username/ai-assistant.nvim",
  requires = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim",
    "nvim-treesitter/nvim-treesitter",
    "rcarriga/nvim-notify", -- optional
  },
  config = function()
    require("ai-assistant").setup({
      -- Optional configuration here
    })
  end
}
```

## Configuration

The plugin comes with sensible defaults, but you can customize it:

```lua
require("ai-assistant").setup({
  provider = {
    default = "openai", -- openai, anthropic, azure, mistral
    openai = {
      api_key = vim.env.OPENAI_API_KEY, -- or set directly: "sk-..."
      api_model = "gpt-4-turbo", -- Model to use
      max_tokens = 2048, -- Max tokens per request
      temperature = 0.7, -- Creativity level
    },
    anthropic = {
      api_key = vim.env.ANTHROPIC_API_KEY,
      api_model = "claude-3-opus-20240229",
    },
    -- Configure other providers similarly
  },
  context = {
    enable_project_context = true, -- Include project files in context
    enable_buffer_context = true, -- Include current buffer in context
    max_context_tokens = 7000, -- Max context size in tokens
    max_files = 10, -- Max files to include in context
    exclusions = {
      file_patterns = { "%.git/", "node_modules/", "%.png$" }, -- Patterns to exclude
      paths = { "dist", "build" }, -- Specific paths to exclude
      max_file_size = 1048576, -- 1MB max file size
    },
  },
  ui = {
    panel = {
      position = "right", -- top, right, bottom, left
      size = 0.4, -- 0.0-1.0 representing percentage of editor size
      border = "rounded", -- none, single, double, rounded, solid, shadow
    },
  },
  keymaps = {
    toggle_panel = "<leader>ai", -- Toggle AI panel
    context_menu = "<leader>ac", -- Open context menu
    inline_completion = "<C-a>", -- Trigger inline completion
  },
})
```

## Usage

### Commands

- `:AIPanel` - Toggle the AI assistance panel
- `:AIExplain` - Explain selected code (visual mode)
- `:AIRefactor` - Refactor selected code (visual mode)
- `:AIDocument` - Add documentation to selected code (visual mode)
- `:AITest` - Generate tests for selected code (visual mode)
- `:AIProvider [name]` - Display or set the current AI provider
- `:AIClearContext` - Clear the context cache

### Panel Interface

The panel interface allows you to interact with the AI assistant:
- Type your prompt in the input area
- Press `<Enter>` to submit
- View the response in the output area
- Use `<Esc>` to close the panel

### API Usage

You can use the plugin programmatically:

```lua
local ai = require("ai-assistant")

-- Send a query to the AI
local response = ai.query("Explain how promises work in JavaScript")

-- Stream a response with callback
local request_id = ai.stream_query("Generate a function that...", function(chunk)
  if chunk.content then
    print(chunk.content)
  elseif chunk.finish_reason then
    print("Done!")
  end
end)

-- Cancel a request
ai.cancel_query(request_id)

-- Open the panel with a prepared prompt
ai.open_panel({ with_prompt = "Explain this code:\n```\nfunction example() {...}\n```" })

-- Explain code
local code = "function add(a, b) { return a + b }"
local explanation = ai.explain_code(code, { with_focus = "performance" })
```

### Telescope Integration

If you have Telescope installed, you can use these additional commands:

```lua
:Telescope ai_providers  -- Select AI provider
:Telescope ai_context    -- Browse and select context files
```

## Requirements

- Neovim >= 0.7.0
- curl (for API requests)
- plenary.nvim
- nui.nvim
- Optional but recommended:
  - nvim-treesitter
  - telescope.nvim
  - nvim-notify

## License

MIT
