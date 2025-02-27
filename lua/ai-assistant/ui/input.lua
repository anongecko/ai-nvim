local config = require("ai-assistant.config")
local utils = require("ai-assistant.utils")
local log = utils.log

-- Check for nui.nvim
local has_nui, nui = pcall(require, "nui.popup")
if not has_nui then
  log.error("nui.nvim is required for UI components")
end

local M = {
  _history = {},
  _history_idx = 0,
}

function M.input(prompt, options, callback)
  if not has_nui then
    -- Fallback to vim.ui.input if nui is not available
    vim.ui.input({
      prompt = prompt,
      default = options and options.default,
    }, callback)
    return
  end
  
  options = options or {}
  local width = options.width or 60
  local height = options.height or 1
  local default = options.default or ""
  local multiline = options.multiline or false
  local title = options.title or "AI Assistant Input"
  
  if height > 1 then
    multiline = true
  end
  
  -- Calculate position
  local row = options.row or math.floor((vim.o.lines - height) / 2)
  local col = options.col or math.floor((vim.o.columns - width) / 2)
  
  local input = nui.Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = " " .. title .. " ",
        top_align = "center",
      },
    },
    position = {
      row = row,
      col = col,
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
    },
  })
  
  -- Mount the popup
  input:mount()
  
  -- Set prompt
  if prompt and prompt ~= "" then
    local width_without_borders = width - 2
    if #prompt > width_without_borders then
      -- Wrap the prompt
      local lines = {}
      local current_line = ""
      for word in prompt:gmatch("%S+") do
        if #current_line + #word + 1 > width_without_borders then
          table.insert(lines, current_line)
          current_line = word
        else
          if current_line == "" then
            current_line = word
          else
            current_line = current_line .. " " .. word
          end
        end
      end
      if current_line ~= "" then
        table.insert(lines, current_line)
      end
      
      -- Insert the prompt lines at the top
      vim.api.nvim_buf_set_lines(input.bufnr, 0, 0, false, lines)
      vim.api.nvim_win_set_cursor(input.winid, {#lines + 1, 0})
      
      -- Increase height to accommodate the prompt
      local new_height = height + #lines
      input:update_layout({
        height = new_height,
        position = {
          row = math.floor((vim.o.lines - new_height) / 2),
          col = col,
        },
      })
    else
      -- Simple one-line prompt
      vim.api.nvim_buf_set_lines(input.bufnr, 0, 0, false, {prompt})
      vim.api.nvim_win_set_cursor(input.winid, {2, 0})
      
      -- Increase height to accommodate the prompt
      input:update_layout({
        height = height + 1,
        position = {
          row = math.floor((vim.o.lines - (height + 1)) / 2),
          col = col,
        },
      })
    end
  end
  
  -- Set default value
  if default and default ~= "" then
    local cursor_line = vim.api.nvim_win_get_cursor(input.winid)[1]
    vim.api.nvim_buf_set_lines(input.bufnr, cursor_line - 1, cursor_line - 1, false, {default})
    vim.api.nvim_win_set_cursor(input.winid, {cursor_line, #default})
  end
  
  -- Start in insert mode
  vim.cmd("startinsert!")
  
  -- Submit handler
  local function submit()
    local cursor_line = vim.api.nvim_win_get_cursor(input.winid)[1]
    local lines = vim.api.nvim_buf_get_lines(input.bufnr, cursor_line - 1, -1, false)
    local value = table.concat(lines, "\n")
    
    -- Add to history if not empty and different from last entry
    if value ~= "" and (M._history[#M._history] ~= value) then
      table.insert(M._history, value)
      M._history_idx = #M._history + 1
    end
    
    input:unmount()
    if callback then
      callback(value)
    end
  end
  
  -- Set up keymaps
  if multiline then
    vim.api.nvim_buf_set_keymap(input.bufnr, "i", "<C-CR>", "", {
      noremap = true,
      callback = submit
    })
    
    vim.api.nvim_buf_set_keymap(input.bufnr, "n", "<C-CR>", "", {
      noremap = true,
      callback = submit
    })
  else
    vim.api.nvim_buf_set_keymap(input.bufnr, "i", "<CR>", "", {
      noremap = true,
      callback = submit
    })
    
    vim.api.nvim_buf_set_keymap(input.bufnr, "n", "<CR>", "", {
      noremap = true,
      callback = submit
    })
  end
  
  vim.api.nvim_buf_set_keymap(input.bufnr, "n", "<Esc>", "", {
    noremap = true,
    callback = function()
      input:unmount()
      if callback then
        callback(nil)
      end
    end
  })
  
  vim.api.nvim_buf_set_keymap(input.bufnr, "i", "<C-c>", "", {
    noremap = true,
    callback = function()
      input:unmount()
      if callback then
        callback(nil)
      end
    end
  })
  
  -- History navigation
  vim.api.nvim_buf_set_keymap(input.bufnr, "i", "<C-p>", "", {
    noremap = true,
    callback = function()
      if #M._history == 0 or M._history_idx <= 0 then
        return
      end
      
      M._history_idx = math.max(1, M._history_idx - 1)
      local prev_input = M._history[M._history_idx]
      
      local cursor_line = vim.api.nvim_win_get_cursor(input.winid)[1]
      vim.api.nvim_buf_set_lines(input.bufnr, cursor_line - 1, cursor_line, false, {prev_input})
      vim.api.nvim_win_set_cursor(input.winid, {cursor_line, #prev_input})
    end
  })
  
  vim.api.nvim_buf_set_keymap(input.bufnr, "i", "<C-n>", "", {
    noremap = true,
    callback = function()
      if #M._history == 0 or M._history_idx >= #M._history then
        M._history_idx = #M._history + 1
        local cursor_line = vim.api.nvim_win_get_cursor(input.winid)[1]
        vim.api.nvim_buf_set_lines(input.bufnr, cursor_line - 1, cursor_line, false, {""})
        vim.api.nvim_win_set_cursor(input.winid, {cursor_line, 0})
        return
      end
      
      M._history_idx = math.min(#M._history, M._history_idx + 1)
      local next_input = M._history[M._history_idx]
      
      local cursor_line = vim.api.nvim_win_get_cursor(input.winid)[1]
      vim.api.nvim_buf_set_lines(input.bufnr, cursor_line - 1, cursor_line, false, {next_input})
      vim.api.nvim_win_set_cursor(input.winid, {cursor_line, #next_input})
    end
  })
  
  return input
end

function M.select(items, options, callback)
  if not has_nui then
    -- No fallback for select; we need nui
    log.error("nui.nvim is required for select UI")
    return
  end
  
  options = options or {}
  local width = options.width or 60
  local title = options.title or "AI Assistant Select"
  local prompt = options.prompt or "Select an item:"
  
  -- Calculate height based on items plus prompt
  local height = #items + 1 -- items + prompt
  if height > 20 then height = 20 end -- Max height
  
  local select = nui.Popup({
    enter = true,
    focusable = true,
    border = {
      style = "rounded",
      text = {
        top = " " .. title .. " ",
        top_align = "center",
        bottom = " <CR>:select <Esc>:cancel ",
        bottom_align = "center",
      },
    },
    position = "50%",
    size = {
      width = width,
      height = height + 1, -- +1 for prompt
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
  select:mount()
  
  -- Add prompt
  vim.api.nvim_buf_set_lines(select.bufnr, 0, 0, false, {prompt})
  
  -- Add items
  local display_items = {}
  for i, item in ipairs(items) do
    if type(item) == "table" and item.text then
      table.insert(display_items, string.format("%d. %s", i, item.text))
    else
      table.insert(display_items, string.format("%d. %s", i, tostring(item)))
    end
  end
  
  vim.api.nvim_buf_set_lines(select.bufnr, 1, 1, false, display_items)
  
  -- Set cursor position to the first item
  vim.api.nvim_win_set_cursor(select.winid, {2, 0})
  
  -- Set up keymaps
  vim.api.nvim_buf_set_keymap(select.bufnr, "n", "<CR>", "", {
    noremap = true,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(select.winid)
      local idx = cursor[1] - 1 -- -1 for prompt
      if idx > 0 and idx <= #items then
        select:unmount()
        if callback then
          callback(items[idx], idx)
        end
      end
    end
  })
  
  vim.api.nvim_buf_set_keymap(select.bufnr, "n", "<Esc>", "", {
    noremap = true,
    callback = function()
      select:unmount()
      if callback then
        callback(nil)
      end
    end
  })
  
  vim.api.nvim_buf_set_keymap(select.bufnr, "n", "q", "", {
    noremap = true,
    callback = function()
      select:unmount()
      if callback then
        callback(nil)
      end
    end
  })
  
  return select
end

function M.clear_history()
  M._history = {}
  M._history_idx = 0
end

return M
