local config = require("ai-assistant.config")
local utils = require("ai-assistant.utils")
local log = utils.log
local diff = utils.diff

-- Check for nui.nvim
local has_nui, nui = pcall(require, "nui.popup")
if not has_nui then
  log.error("nui.nvim is required for UI components")
end

local M = {
  _preview = nil,
  _diff_ns = vim.api.nvim_create_namespace("ai_assistant_diff"),
}

local function highlight_diff(bufnr, old_text, new_text)
  local cfg = config.get()
  local highlights = cfg.ui.preview.highlights
  
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, M._diff_ns, 0, -1)
  
  -- Compute line diff
  local old_lines = vim.split(old_text, "\n")
  local new_lines = vim.split(new_text, "\n")
  local line_diff = diff.compute_line_diff(old_lines, new_lines)
  
  -- Apply highlights
  for _, d in ipairs(line_diff) do
    local hl_group = highlights.change
    
    if d.type == "add" then
      hl_group = highlights.add
    elseif d.type == "delete" then
      hl_group = highlights.delete
    end
    
    vim.api.nvim_buf_add_highlight(bufnr, M._diff_ns, hl_group, d.line, 0, -1)
  end
end

function M.show(old_text, new_text, title)
  if not has_nui then
    log.error("nui.nvim is required for UI components")
    return
  end
  
  if M._preview and M._preview.winid and vim.api.nvim_win_is_valid(M._preview.winid) then
    M._preview:unmount()
  end
  
  local cfg = config.get()
  title = title or "AI Preview"
  
  -- Calculate size and position
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  
  M._preview = nui.Popup({
    enter = true,
    focusable = true,
    border = {
      style = cfg.ui.preview.border,
      text = {
        top = " " .. title .. " ",
        top_align = "center",
      },
    },
    position = {
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
    },
    size = {
      width = width,
      height = height,
    },
    buf_options = {
      modifiable = true,
      readonly = false,
    },
    win_options = {
      wrap = true,
      linebreak = true,
      cursorline = true,
    },
  })
  
  -- Mount the popup
  M._preview:mount()
  
  -- Set buffer content to new text
  vim.api.nvim_buf_set_lines(M._preview.bufnr, 0, -1, false, vim.split(new_text, "\n"))
  
  -- Highlight differences
  highlight_diff(M._preview.bufnr, old_text, new_text)
  
  -- Set up keymaps
  vim.api.nvim_buf_set_keymap(M._preview.bufnr, "n", "q", "", {
    noremap = true,
    callback = function()
      M._preview:unmount()
    end
  })
  
  vim.api.nvim_buf_set_keymap(M._preview.bufnr, "n", "<Esc>", "", {
    noremap = true,
    callback = function()
      M._preview:unmount()
    end
  })
  
  return M._preview
end

function M.show_diff(old_text, new_text, title)
  if not has_nui then
    log.error("nui.nvim is required for UI components")
    return
  end
  
  if M._preview and M._preview.winid and vim.api.nvim_win_is_valid(M._preview.winid) then
    M._preview:unmount()
  end
  
  local cfg = config.get()
  title = title or "AI Diff Preview"
  
  -- Calculate size and position
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  
  M._preview = nui.Popup({
    enter = true,
    focusable = true,
    border = {
      style = cfg.ui.preview.border,
      text = {
        top = " " .. title .. " ",
        top_align = "center",
      },
    },
    position = {
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
    },
    size = {
      width = width,
      height = height,
    },
    buf_options = {
      modifiable = true,
      readonly = false,
      filetype = "diff",
    },
    win_options = {
      wrap = true,
      linebreak = true,
      cursorline = true,
    },
  })
  
  -- Mount the popup
  M._preview:mount()
  
  -- Generate formatted diff
  local diff_text = diff.format_diff(old_text, new_text)
  
  -- Set buffer content to diff
  vim.api.nvim_buf_set_lines(M._preview.bufnr, 0, -1, false, vim.split(diff_text, "\n"))
  
  -- Set up keymaps
  vim.api.nvim_buf_set_keymap(M._preview.bufnr, "n", "q", "", {
    noremap = true,
    callback = function()
      M._preview:unmount()
    end
  })
  
  vim.api.nvim_buf_set_keymap(M._preview.bufnr, "n", "<Esc>", "", {
    noremap = true,
    callback = function()
      M._preview:unmount()
    end
  })
  
  return M._preview
end

function M.close()
  if M._preview and M._preview.winid and vim.api.nvim_win_is_valid(M._preview.winid) then
    M._preview:unmount()
    M._preview = nil
  end
end

return M
