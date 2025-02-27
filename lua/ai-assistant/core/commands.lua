local config = require("ai-assistant.config")
local provider = require("ai-assistant.provider")
local context = require("ai-assistant.context")
local ui = require("ai-assistant.ui.panel")
local utils = require("ai-assistant.utils")
local log = utils.log

local M = {
  _commands = {},
}

local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]
  
  local lines = vim.fn.getline(start_line, end_line)
  if #lines == 0 then return "" end
  
  lines[1] = lines[1]:sub(start_col)
  lines[#lines] = lines[#lines]:sub(1, end_col)
  
  return table.concat(lines, "\n")
end

local function explain_command(args, range)
  if not range then
    log.error("No selection for explanation")
    return
  end
  
  local code = get_visual_selection()
  if code == "" then
    log.error("Empty selection")
    return
  end
  
  ui.open()
  ui.set_input("Explain the following code:\n```\n" .. code .. "\n```")
  ui.submit()
end

local function refactor_command(args, range)
  if not range then
    log.error("No selection for refactoring")
    return
  end
  
  local code = get_visual_selection()
  if code == "" then
    log.error("Empty selection")
    return
  end
  
  ui.open()
  ui.set_input("Refactor the following code to improve its performance, readability, and maintainability:\n```\n" .. code .. "\n```")
  ui.submit()
end

local function document_command(args, range)
  if not range then
    log.error("No selection for documentation")
    return
  end
  
  local code = get_visual_selection()
  if code == "" then
    log.error("Empty selection")
    return
  end
  
  ui.open()
  ui.set_input("Add detailed documentation to the following code:\n```\n" .. code .. "\n```")
  ui.submit()
end

local function test_command(args, range)
  if not range then
    log.error("No selection for test generation")
    return
  end
  
  local code = get_visual_selection()
  if code == "" then
    log.error("Empty selection")
    return
  end
  
  ui.open()
  ui.set_input("Generate comprehensive unit tests for the following code:\n```\n" .. code .. "\n```")
  ui.submit()
end

local function set_provider_command(args)
  local provider_name = args[1]
  if not provider_name or provider_name == "" then
    -- Display current provider
    local current = provider.get_current()
    log.info("Current provider: %s", current.name)
    
    -- List available providers
    local available = provider.list_available()
    log.info("Available providers: %s", table.concat(available, ", "))
    return
  end
  
  -- Set provider
  local success = provider.set_current(provider_name)
  if not success then
    log.error("Failed to set provider to '%s'", provider_name)
    return
  end
  
  log.info("Provider set to '%s'", provider_name)
  
  -- If panel is open, update the title
  if ui._panel and ui._panel.winid and vim.api.nvim_win_is_valid(ui._panel.winid) then
    local panel_title = string.format(" AI Assistant (%s) ", provider_name)
    ui._panel.border:set_text("top", panel_title, "center")
  end
end

local function clear_context_command()
  context.clear_cache()
  log.info("Context cache cleared")
end

function M.setup()
  local cfg = config.get()
  local prefix = cfg.commands.prefix
  
  -- Define commands
  M._commands = {
    -- Panel commands
    {
      cmd = prefix .. "Panel",
      callback = ui.toggle,
      desc = "Toggle AI assistant panel",
    },
    {
      cmd = prefix .. "PanelOpen",
      callback = ui.open,
      desc = "Open AI assistant panel",
    },
    {
      cmd = prefix .. "PanelClose",
      callback = ui.close,
      desc = "Close AI assistant panel",
    },
    
    -- Context commands
    {
      cmd = prefix .. "ClearContext",
      callback = clear_context_command,
      desc = "Clear context cache",
    },
    
    -- Provider commands
    {
      cmd = prefix .. "Provider",
      callback = set_provider_command,
      desc = "Set or display current AI provider",
      nargs = "?",
      complete = function()
        return provider.list_available()
      end,
    },
    
    -- Code commands (with range)
    {
      cmd = prefix .. "Explain",
      callback = explain_command,
      desc = "Explain selected code",
      range = true,
    },
    {
      cmd = prefix .. "Refactor",
      callback = refactor_command,
      desc = "Refactor selected code",
      range = true,
    },
    {
      cmd = prefix .. "Document",
      callback = document_command,
      desc = "Document selected code",
      range = true,
    },
    {
      cmd = prefix .. "Test",
      callback = test_command,
      desc = "Generate tests for selected code",
      range = true,
    },
  }
  
  -- Register commands
  for _, command in ipairs(M._commands) do
    vim.api.nvim_create_user_command(command.cmd, function(opts)
      command.callback(opts.fargs, opts.range > 0)
    end, {
      desc = command.desc,
      nargs = command.nargs or 0,
      range = command.range or false,
      complete = command.complete,
    })
  end
  
  -- Register keymaps
  local keymaps = cfg.keymaps
  
  if keymaps.toggle_panel then
    vim.keymap.set("n", keymaps.toggle_panel, ui.toggle, { desc = "Toggle AI assistant panel" })
  end
  
  log.debug("Commands setup complete")
  return true
end

return M
