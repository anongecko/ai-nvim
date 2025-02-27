local has_telescope, telescope = pcall(require, "telescope")
local utils = require("ai-assistant.utils")
local log = utils.log
local provider = require("ai-assistant.provider")
local context = require("ai-assistant.context")

local M = {}

local function setup_providers_picker()
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  
  local function entry_maker(provider_name)
    local current = provider.get_current()
    local is_current = current and current.name == provider_name
    
    return {
      value = provider_name,
      display = provider_name .. (is_current and " (current)" or ""),
      ordinal = provider_name,
    }
  end
  
  local provider_names = provider.list_available()
  
  return function(opts)
    opts = opts or {}
    
    pickers.new(opts, {
      prompt_title = "AI Providers",
      finder = finders.new_table {
        results = provider_names,
        entry_maker = entry_maker,
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          provider.set_current(selection.value)
          log.info("Provider set to: %s", selection.value)
        end)
        return true
      end,
    }):find()
  end
end

local function setup_context_picker()
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  
  local function get_context_files()
    local root_dir = context.get_project_root()
    if not root_dir then
      return {}
    end
    
    local cfg = require("ai-assistant.config").get()
    local exclusions = cfg.context.exclusions
    local max_files = cfg.context.max_files
    
    local files = {}
    
    -- Use ripgrep if available for better performance
    if vim.fn.executable("rg") == 1 then
      local cmd = string.format(
        "rg --files --hidden --no-ignore-vcs --glob '!.git' --glob '!node_modules' %s",
        root_dir
      )
      
      local output = vim.fn.systemlist(cmd)
      
      for _, file_path in ipairs(output) do
        if #files >= max_files then
          break
        end
        
        local is_excluded = false
        for _, pattern in ipairs(exclusions.file_patterns) do
          if file_path:match(pattern) then
            is_excluded = true
            break
          end
        end
        
        for _, excluded_path in ipairs(exclusions.paths) do
          if file_path:match(excluded_path .. "$") or file_path:match(excluded_path .. "/") then
            is_excluded = true
            break
          end
        end
        
        if not is_excluded then
          local rel_path = utils.path.relative(file_path, root_dir)
          table.insert(files, {
            path = file_path,
            rel_path = rel_path,
          })
        end
      end
    end
    
    return files
  end
  
  return function(opts)
    opts = opts or {}
    
    local files = get_context_files()
    
    pickers.new(opts, {
      prompt_title = "Context Files",
      finder = finders.new_table {
        results = files,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.rel_path,
            ordinal = entry.rel_path,
            path = entry.path,
          }
        end,
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          vim.cmd("edit " .. selection.path)
        end)
        
        -- Add custom key to preview file content
        map("i", "<C-p>", function()
          local selection = action_state.get_selected_entry()
          local content = utils.fs.read_file(selection.path)
          if content then
            vim.schedule(function()
              vim.api.nvim_echo({{"File Content: " .. selection.display .. "\n", "Title"}, {content, "Normal"}}, true, {})
            end)
          end
        end)
        
        return true
      end,
    }):find()
  end
end

function M.setup(opts)
  if not has_telescope then
    log.error("telescope.nvim is required for telescope integration")
    return false
  end
  
  -- Register extensions
  telescope.register_extension {
    exports = {
      ai_providers = setup_providers_picker(),
      ai_context = setup_context_picker(),
    }
  }
  
  return true
end

return M
