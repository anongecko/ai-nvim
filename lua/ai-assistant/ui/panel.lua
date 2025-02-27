local config = require("ai-assistant.config")
local provider = require("ai-assistant.provider")
local context = require("ai-assistant.context")
local utils = require("ai-assistant.utils")
local log = utils.log

-- Check for nui.nvim
local has_nui, nui = pcall(require, "nui.popup")
if not has_nui then
  log.error("nui.nvim is required for UI components")
end

local M = {
  _panel = nil,
  _input = nil,
  _output = nil,
  _is_streaming = false,
  _current_request_id = nil,
}

local function create_panel()
  local cfg = config.get()
  local panel_cfg = cfg.ui.panel
  
  local width, height, anchor = 80, 20, "SE"
  local position = panel_cfg.position
  
  -- Calculate dimensions based on editor size and position
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines
  
  if position == "right" then
    width = math.floor(editor_width * panel_cfg.size)
    height = editor_height - 4
    anchor = "NE"
  elseif position == "left" then
    width = math.floor(editor_width * panel_cfg.size)
    height = editor_height - 4
    anchor = "NW"
  elseif position == "top" then
    width = editor_width - 4
    height = math.floor(editor_height * panel_cfg.size)
    anchor = "NW"
  elseif position == "bottom" then
    width = editor_width - 4
    height = math.floor(editor_height * panel_cfg.size)
    anchor = "SW"
  end
  
  -- Create main panel popup
  local panel = nui.Popup({
    enter = true,
    focusable = true,
    border = {
      style = panel_cfg.border,
      text = {
        top = " AI Assistant ",
        top_align = "center",
      },
    },
    position = {
      row = position == "bottom" and editor_height - height - 2 or 1,
      col = position == "right" and editor_width - width - 1 or 1,
    },
    size = {
      width = width,
      height = height,
    },
    buf_options = {
      modifiable = true,
      readonly = false,
      filetype = "markdown",
    },
    win_options = {
      wrap = true,
      linebreak = true,
      cursorline = true,
      winhighlight = "Normal:" .. panel_cfg.highlights.background,
    },
  })
  
  -- Create output buffer (top part of panel)
  local output_height = height - 8
  local output = nui.Popup({
    enter = false,
    focusable = true,
    border = {
      style = panel_cfg.border,
      text = {
        top = " Response ",
        top_align = "center",
      },
    },
    position = {
      row = 1,
      col = 1,
    },
    size = {
      width = width - 2,
      height = output_height,
    },
    buf_options = {
      modifiable = true,
      readonly = false,
      filetype = "markdown",
    },
    win_options = {
      wrap = true,
      linebreak = true,
      winhighlight = "Normal:" .. panel_cfg.highlights.background,
    },
  })
  
  -- Create input buffer (bottom part of panel)
  local input = nui.Popup({
    enter = true,
    focusable = true,
    border = {
      style = panel_cfg.border,
      text = {
        top = " Prompt ",
        top_align = "center",
      },
    },
    position = {
      row = output_height + 3,
      col = 1,
    },
    size = {
      width = width - 2,
      height = 6,
    },
    buf_options = {
      modifiable = true,
      readonly = false,
    },
    win_options = {
      wrap = true,
      linebreak = true,
      winhighlight = "Normal:" .. panel_cfg.highlights.background,
    },
  })
  
  return {
    panel = panel,
    output = output,
    input = input,
  }
end

local function setup_keymaps()
  local input_bufnr = M._input.bufnr
  local output_bufnr = M._output.bufnr
  local panel_bufnr = M._panel.bufnr
  
  -- Submit prompt on <Enter> in input buffer
  vim.api.nvim_buf_set_keymap(input_bufnr, "i", "<CR>", "", {
    noremap = true,
    callback = function()
      -- Only submit if Ctrl/Shift is not pressed
      if not vim.fn.getcharmod() % 2 == 0 then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
        return
      end
      
      M.submit()
    end
  })
  
  -- Close panel on <Esc>
  for _, bufnr in ipairs({input_bufnr, output_bufnr, panel_bufnr}) do
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", "", {
      noremap = true,
      callback = M.close
    })
    
    -- Cancel streaming with <C-c>
    vim.api.nvim_buf_set_keymap(bufnr, "n", "<C-c>", "", {
      noremap = true,
      callback = M.cancel
    })
  end
  
  -- Focus input with i in output buffer
  vim.api.nvim_buf_set_keymap(output_bufnr, "n", "i", "", {
    noremap = true,
    callback = function()
      vim.api.nvim_set_current_win(M._input.winid)
      vim.cmd("startinsert")
    end
  })
  
  -- Focus output with <C-o> in input buffer
  vim.api.nvim_buf_set_keymap(input_bufnr, "i", "<C-o>", "", {
    noremap = true,
    callback = function()
      vim.api.nvim_set_current_win(M._output.winid)
    end
  })
  
  -- Clear input with <C-l>
  vim.api.nvim_buf_set_keymap(input_bufnr, "i", "<C-l>", "", {
    noremap = true,
    callback = M.clear_input
  })
  
  -- Clear output with <C-l>
  vim.api.nvim_buf_set_keymap(output_bufnr, "n", "<C-l>", "", {
    noremap = true,
    callback = M.clear_output
  })
end

function M.mount_panel()
  if not has_nui then
    log.error("nui.nvim is required for UI components")
    return false
  end
  
  if M._panel and M._panel.winid and vim.api.nvim_win_is_valid(M._panel.winid) then
    -- Focus existing panel
    vim.api.nvim_set_current_win(M._panel.winid)
    return true
  end
  
  local components = create_panel()
  
  M._panel = components.panel
  M._output = components.output
  M._input = components.input
  
  -- Mount panel
  M._panel:mount()
  
  -- Mount components relative to panel
  M._output:mount()
  M._input:mount()
  
  -- Set up keymaps
  setup_keymaps()
  
  -- Focus input
  vim.api.nvim_set_current_win(M._input.winid)
  vim.cmd("startinsert")
  
  return true
end

function M.close()
  if M._is_streaming and M._current_request_id then
    provider.cancel(M._current_request_id)
    M._is_streaming = false
    M._current_request_id = nil
  end
  
  if M._input and M._input.winid and vim.api.nvim_win_is_valid(M._input.winid) then
    M._input:unmount()
  end
  
  if M._output and M._output.winid and vim.api.nvim_win_is_valid(M._output.winid) then
    M._output:unmount()
  end
  
  if M._panel and M._panel.winid and vim.api.nvim_win_is_valid(M._panel.winid) then
    M._panel:unmount()
  end
  
  M._panel = nil
  M._input = nil
  M._output = nil
end

function M.toggle()
  if M._panel and M._panel.winid and vim.api.nvim_win_is_valid(M._panel.winid) then
    M.close()
  else
    M.open()
  end
end

function M.open()
  if not M.mount_panel() then
    return
  end
  
  -- Set panel title with current provider
  local current_provider = provider.get_current()
  local panel_title = string.format(" AI Assistant (%s) ", current_provider.name)
  
  M._panel.border:set_text("top", panel_title, "center")
end

function M.set_input(text)
  if not M._input or not M._input.bufnr or not vim.api.nvim_buf_is_valid(M._input.bufnr) then
    return
  end
  
  vim.api.nvim_buf_set_option(M._input.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(M._input.bufnr, 0, -1, false, vim.split(text, "\n"))
  vim.api.nvim_buf_set_option(M._input.bufnr, "modified", false)
end

function M.get_input()
  if not M._input or not M._input.bufnr or not vim.api.nvim_buf_is_valid(M._input.bufnr) then
    return ""
  end
  
  local lines = vim.api.nvim_buf_get_lines(M._input.bufnr, 0, -1, false)
  return table.concat(lines, "\n")
end

function M.clear_input()
  if not M._input or not M._input.bufnr or not vim.api.nvim_buf_is_valid(M._input.bufnr) then
    return
  end
  
  vim.api.nvim_buf_set_option(M._input.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(M._input.bufnr, 0, -1, false, {""})
  vim.api.nvim_buf_set_option(M._input.bufnr, "modified", false)
end

function M.set_output(text)
  if not M._output or not M._output.bufnr or not vim.api.nvim_buf_is_valid(M._output.bufnr) then
    return
  end
  
  vim.api.nvim_buf_set_option(M._output.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(M._output.bufnr, 0, -1, false, vim.split(text, "\n"))
  vim.api.nvim_buf_set_option(M._output.bufnr, "modified", false)
  vim.api.nvim_buf_set_option(M._output.bufnr, "modifiable", false)
end

function M.append_output(text)
  if not M._output or not M._output.bufnr or not vim.api.nvim_buf_is_valid(M._output.bufnr) then
    return
  end
  
  vim.api.nvim_buf_set_option(M._output.bufnr, "modifiable", true)
  
  local lines = vim.api.nvim_buf_get_lines(M._output.bufnr, 0, -1, false)
  local new_lines = vim.split(text, "\n")
  
  if #lines == 1 and lines[1] == "" then
    vim.api.nvim_buf_set_lines(M._output.bufnr, 0, -1, false, new_lines)
  else
    local last_line = lines[#lines]
    local first_new_line = new_lines[1]
    
    -- Append to the last line
    lines[#lines] = last_line .. first_new_line
    
    -- Add remaining lines
    for i = 2, #new_lines do
      table.insert(lines, new_lines[i])
    end
    
    vim.api.nvim_buf_set_lines(M._output.bufnr, 0, -1, false, lines)
  end
  
  -- Scroll to bottom
  local line_count = vim.api.nvim_buf_line_count(M._output.bufnr)
  vim.api.nvim_win_set_cursor(M._output.winid, {line_count, 0})
  
  vim.api.nvim_buf_set_option(M._output.bufnr, "modified", false)
  vim.api.nvim_buf_set_option(M._output.bufnr, "modifiable", false)
end

function M.clear_output()
  if not M._output or not M._output.bufnr or not vim.api.nvim_buf_is_valid(M._output.bufnr) then
    return
  end
  
  vim.api.nvim_buf_set_option(M._output.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(M._output.bufnr, 0, -1, false, {""})
  vim.api.nvim_buf_set_option(M._output.bufnr, "modified", false)
  vim.api.nvim_buf_set_option(M._output.bufnr, "modifiable", false)
end

function M.submit()
  if M._is_streaming then
    log.warn("Already streaming a response")
    return
  end
  
  local prompt = M.get_input()
  if not prompt or prompt == "" then
    log.warn("No prompt to submit")
    return
  end
  
  M.clear_output()
  M._output.border:set_text("top", " Response (Generating...) ", "center")
  
  -- Get context
  local ctx = context.build_context()
  
  -- Start streaming response
  M._is_streaming = true
  M._current_request_id = provider.stream_response(prompt, ctx, {}, function(chunk)
    if chunk.error then
      M._output.border:set_text("top", " Response (Error) ", "center")
      M.append_output("\nError: " .. chunk.error)
      M._is_streaming = false
      return
    end
    
    if chunk.finish_reason then
      M._output.border:set_text("top", " Response (Complete) ", "center")
      M._is_streaming = false
      M._current_request_id = nil
      return
    end
    
    if chunk.content then
      M.append_output(chunk.content)
    end
  end)
  
  -- Clear input after submission
  M.clear_input()
end

function M.cancel()
  if not M._is_streaming or not M._current_request_id then
    return
  end
  
  provider.cancel(M._current_request_id)
  M._is_streaming = false
  M._current_request_id = nil
  
  M._output.border:set_text("top", " Response (Cancelled) ", "center")
  M.append_output("\n\n[Response cancelled]")
end

return M
