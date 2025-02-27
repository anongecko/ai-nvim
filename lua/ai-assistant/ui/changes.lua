local config = require("ai-assistant.config")
local utils = require("ai-assistant.utils")
local diff = require("ai-assistant.utils.diff")
local changes = require("ai-assistant.core.changes")
local log = utils.log

-- Check for nui.nvim
local has_nui, nui = pcall(require, "nui.popup")
if not has_nui then
  log.error("nui.nvim is required for UI components")
end

local M = {
  _popup = nil,
  _diff_ns = vim.api.nvim_create_namespace("ai_assistant_changes"),
}

function M.preview_changes(old_text, new_text, options)
  if not has_nui then
    log.error("nui.nvim is required for UI components")
    return
  end
  
  options = options or {}
  local title = options.title or "AI Changes Preview"
  local apply_callback = options.on_apply
  
  if M._popup and M._popup.winid and vim.api.nvim_win_is_valid(M._popup.winid) then
    M._popup:unmount()
  end
  
  local cfg = config.get()
  
  -- Calculate size and position
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  
  M._popup = nui.Popup({
    enter = true,
    focusable = true,
    border = {
      style = cfg.ui.preview.border,
      text = {
        top = " " .. title .. " ",
        top_align = "center",
        bottom = " <a>:apply <q>:close <diff>:toggle view ",
        bottom_align = "center",
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
  M._popup:mount()
  
  -- Store the texts for toggling view
  M._popup.old_text = old_text
  M._popup.new_text = new_text
  M._popup.view_mode = "new" -- Start with new text view
  
  -- Set initial content to new text
  vim.api.nvim_buf_set_lines(M._popup.bufnr, 0, -1, false, vim.split(new_text, "\n"))
  
  -- Set up keymaps
  vim.api.nvim_buf_set_keymap(M._popup.bufnr, "n", "q", "", {
    noremap = true,
    callback = function()
      M._popup:unmount()
    end
  })
  
  vim.api.nvim_buf_set_keymap(M._popup.bufnr, "n", "<Esc>", "", {
    noremap = true,
    callback = function()
      M._popup:unmount()
    end
  })
  
  vim.api.nvim_buf_set_keymap(M._popup.bufnr, "n", "a", "", {
    noremap = true,
    callback = function()
      M._popup:unmount()
      if apply_callback then
        apply_callback(new_text)
      end
    end
  })
  
  vim.api.nvim_buf_set_keymap(M._popup.bufnr, "n", "diff", "", {
    noremap = true,
    callback = function()
      M.toggle_view()
    end
  })
  
  return M._popup
end

function M.toggle_view()
  if not M._popup or not M._popup.winid or not vim.api.nvim_win_is_valid(M._popup.winid) then
    return
  end
  
  if M._popup.view_mode == "new" then
    -- Switch to diff view
    M._popup.view_mode = "diff"
    local diff_text = diff.format_diff(M._popup.old_text, M._popup.new_text)
    vim.api.nvim_buf_set_option(M._popup.bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(M._popup.bufnr, 0, -1, false, vim.split(diff_text, "\n"))
    vim.api.nvim_buf_set_option(M._popup.bufnr, "filetype", "diff")
    vim.api.nvim_buf_set_option(M._popup.bufnr, "modifiable", false)
  elseif M._popup.view_mode == "diff" then
    -- Switch to old view
    M._popup.view_mode = "old"
    vim.api.nvim_buf_set_option(M._popup.bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(M._popup.bufnr, 0, -1, false, vim.split(M._popup.old_text, "\n"))
    vim.api.nvim_buf_set_option(M._popup.bufnr, "filetype", "")
    vim.api.nvim_buf_set_option(M._popup.bufnr, "modifiable", false)
  else
    -- Switch to new view
    M._popup.view_mode = "new"
    vim.api.nvim_buf_set_option(M._popup.bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(M._popup.bufnr, 0, -1, false, vim.split(M._popup.new_text, "\n"))
    vim.api.nvim_buf_set_option(M._popup.bufnr, "filetype", "")
    vim.api.nvim_buf_set_option(M._popup.bufnr, "modifiable", true)
  end
end

function M.apply_changes_dialog(old_text, new_text, options)
  options = options or {}
  
  local bufnr = options.bufnr or vim.api.nvim_get_current_buf()
  local description = options.description or "AI changes"
  
  M.preview_changes(old_text, new_text, {
    title = options.title or "Apply Changes?",
    on_apply = function(text)
      -- Create and apply the change
      local change = changes.create_change(description, old_text, new_text, bufnr)
      changes.apply_change(change)
      
      if options.on_applied then
        options.on_applied(change)
      end
    end
  })
end

function M.show_change_history()
  if not has_nui then
    log.error("nui.nvim is required for UI components")
    return
  end
  
  local history = changes.get_history()
  if #history == 0 then
    vim.notify("No change history available", vim.log.levels.INFO)
    return
  end
  
  -- Calculate size and position
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  
  local popup = nui.Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = " Change History ",
        top_align = "center",
        bottom = " <Enter>:view <Esc>:close ",
        bottom_align = "center",
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
      wrap = false,
      cursorline = true,
    },
  })
  
  -- Mount the popup
  popup:mount()
  
  -- Populate with history items
  local lines = {}
  for i, change in ipairs(history) do
    local timestamp = os.date("%Y-%m-%d %H:%M:%S", change.timestamp)
    table.insert(lines, string.format("%d. [%s] %s", i, timestamp, change.description))
  end
  
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  
  -- Set up keymaps
  vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "<Esc>", "", {
    noremap = true,
    callback = function()
      popup:unmount()
    end
  })
  
  vim.api.nvim_buf_set_keymap(popup.bufnr, "n", "<CR>", "", {
    noremap = true,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(popup.winid)
      local idx = cursor[1]
      if idx > 0 and idx <= #history then
        local change = history[idx]
        popup:unmount()
        
        M.preview_changes(change.old_text, change.new_text, {
          title = "Change: " .. change.description,
          on_apply = function()
            local bufnr = change.bufnr
            if not vim.api.nvim_buf_is_valid(bufnr) then
              bufnr = vim.api.nvim_get_current_buf()
            end
            changes.apply_change(change)
          end
        })
      end
    end
  })
  
  return popup
end

return M
