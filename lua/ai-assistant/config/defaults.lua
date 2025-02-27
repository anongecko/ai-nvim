local path = require("ai-assistant.utils.path")

return {
  -- Core configuration
  enabled = true,
  path = {
    cache = path.join(vim.fn.stdpath("cache"), "ai-assistant"),
    data = path.join(vim.fn.stdpath("data"), "ai-assistant"),
    logs = path.join(vim.fn.stdpath("log"), "ai-assistant"),
  },
  
  -- Keymaps for global plugin features
  keymaps = {
    toggle_panel = "<leader>ai",
    context_menu = "<leader>ac",
    inline_completion = "<C-a>",
  },
  
  -- Logging configuration
  log = {
    level = "INFO", -- DEBUG, INFO, WARN, ERROR
    file = nil, -- Set to a file path to enable file logging
  },
  
  -- Provider configuration
  provider = {
    default = "openai", -- openai, anthropic, azure, mistral
    openai = {
      api_key = vim.env.OPENAI_API_KEY,
      api_endpoint = "https://api.openai.com/v1/chat/completions",
      api_model = "gpt-4-turbo",
      fallback_model = "gpt-3.5-turbo",
      max_tokens = 2048,
      temperature = 0.7,
      enable_streaming = true,
      retry_count = 3,
      params = {
        top_p = 1,
        presence_penalty = 0,
        frequency_penalty = 0,
      },
    },
    anthropic = {
      api_key = vim.env.ANTHROPIC_API_KEY,
      api_endpoint = "https://api.anthropic.com/v1/messages",
      api_model = "claude-3-opus-20240229",
      fallback_model = "claude-3-haiku-20240307",
      max_tokens = 2048,
      temperature = 0.7,
      enable_streaming = true,
      retry_count = 3,
      params = {
        top_p = 1,
      },
    },
    azure = {
      api_key = vim.env.AZURE_OPENAI_API_KEY,
      api_endpoint = vim.env.AZURE_OPENAI_ENDPOINT or "",
      api_model = "gpt-4",
      fallback_model = "gpt-35-turbo",
      max_tokens = 2048,
      temperature = 0.7,
      enable_streaming = true,
      retry_count = 3,
      params = {
        top_p = 1,
        presence_penalty = 0,
        frequency_penalty = 0,
      },
    },
    mistral = {
      api_key = vim.env.MISTRAL_API_KEY,
      api_endpoint = "https://api.mistral.ai/v1/chat/completions",
      api_model = "mistral-large-latest",
      fallback_model = "mistral-small-latest",
      max_tokens = 2048,
      temperature = 0.7,
      enable_streaming = true,
      retry_count = 3,
      params = {
        top_p = 1,
      },
    },
  },
  
  -- Context configuration
  context = {
    enable_project_context = true,
    enable_buffer_context = true,
    max_context_tokens = 7000,
    max_file_tokens = 2000,
    max_files = 10,
    exclusions = {
      -- File patterns to exclude
      file_patterns = {
        "%.git/", "node_modules/", "%.cache/", "%.vscode/", "%.idea/",
        "%.DS_Store", "%.png", "%.jpg", "%.jpeg", "%.gif", "%.svg", "%.pdf",
        "%.zip", "%.gz", "%.tar", "%.rar", "%.7z", "%.mp3", "%.mp4", "%.mov",
      },
      -- Specific paths to exclude
      paths = {
        "dist", "build", "out", "target", "venv", ".env", "bin", "obj",
      },
      -- Maximum file size in bytes (default: 1MB)
      max_file_size = 1048576,
    },
  },
  
  -- Panel UI configuration
  ui = {
    panel = {
      position = "right", -- top, right, bottom, left
      size = 0.4, -- 0.0-1.0 representing percentage of editor size
      border = "rounded", -- none, single, double, rounded, solid, shadow
      icons = {
        provider = "󰄛",
        run = "󰑮",
        save = "󰆓",
        close = "󰅖",
      },
      highlights = {
        border = "FloatBorder",
        background = "Normal",
        header = "Title",
        text = "Normal",
        prompt = "String",
      },
    },
    notification = {
      enable = true,
      timeout = 5000, -- milliseconds
    },
    preview = {
      border = "rounded",
      highlights = {
        add = "DiffAdd",
        delete = "DiffDelete",
        change = "DiffChange",
      },
    },
  },
  
  -- Integrations
  integrations = {
    telescope = {
      enable = true,
    },
    treesitter = {
      enable = true,
    },
    file_browser = {
      enable = true,
    },
    nui = {
      enable = true,
    },
    notify = {
      enable = true,
    },
  },
  
  -- Commands configuration
  commands = {
    prefix = "AI",
  },
}
