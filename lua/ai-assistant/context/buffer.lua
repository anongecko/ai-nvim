local utils = require("ai-assistant.utils")
local config = require("ai-assistant.config")
local log = utils.log

local M = {}

function M.get_current_buffer_info()
  local bufnr = vim.api.nvim_get_current_buf()
  local buf_info = {
    bufnr = bufnr,
    path = vim.api.nvim_buf_get_name(bufnr),
    filetype = vim.bo[bufnr].filetype,
    modifiable = vim.bo[bufnr].modifiable,
    modified = vim.bo[bufnr].modified,
    readonly = vim.bo[bufnr].readonly,
    line_count = vim.api.nvim_buf_line_count(bufnr),
    cursor = vim.api.nvim_win_get_cursor(0),
  }
  
  return buf_info
end

function M.extract_context_around_cursor(window_size)
  local cfg = config.get()
  window_size = window_size or 50 -- Default window size
  
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor[1]
  
  local start_line = math.max(1, cursor_line - math.floor(window_size / 2))
  local end_line = math.min(vim.api.nvim_buf_line_count(bufnr), cursor_line + math.floor(window_size / 2))
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  
  -- Mark the cursor line in the context
  if cursor_line >= start_line and cursor_line <= end_line then
    local cursor_idx = cursor_line - start_line + 1
    if lines[cursor_idx] then
      lines[cursor_idx] = lines[cursor_idx] .. " <-- cursor"
    end
  end
  
  local context = table.concat(lines, "\n")
  
  -- Add buffer information
  local buf_info = M.get_current_buffer_info()
  local buffer_context = string.format(
    "# Current Buffer\nFile: %s\nFiletype: %s\nCursor position: Line %d, Column %d\n\n```%s\n%s\n```",
    buf_info.path,
    buf_info.filetype,
    buf_info.cursor[1],
    buf_info.cursor[2],
    buf_info.filetype,
    context
  )
  
  return buffer_context
end

function M.extract_visible_content()
  local bufnr = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  
  local topline = vim.fn.line("w0", win)
  local botline = vim.fn.line("w$", win)
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, topline - 1, botline, false)
  local context = table.concat(lines, "\n")
  
  -- Add buffer information
  local buf_info = M.get_current_buffer_info()
  local buffer_context = string.format(
    "# Visible Content\nFile: %s\nFiletype: %s\nVisible lines: %d-%d\n\n```%s\n%s\n```",
    buf_info.path,
    buf_info.filetype,
    topline,
    botline,
    buf_info.filetype,
    context
  )
  
  return buffer_context
end

function M.extract_current_function()
  -- Try to use treesitter integration if available
  local ok, ts_integration = pcall(require, "ai-assistant.integrations.treesitter")
  if ok then
    local function_text = ts_integration.get_current_function_text()
    if function_text then
      local buf_info = M.get_current_buffer_info()
      local buffer_context = string.format(
        "# Current Function\nFile: %s\nFiletype: %s\n\n```%s\n%s\n```",
        buf_info.path,
        buf_info.filetype,
        buf_info.filetype,
        function_text
      )
      return buffer_context
    end
  end
  
  -- Fallback to simple extraction if treesitter is not available
  return M.extract_context_around_cursor(30)
end

function M.get_current_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]
  
  local lines = vim.fn.getline(start_line, end_line)
  if #lines == 0 then return nil end
  
  lines[1] = lines[1]:sub(start_col)
  lines[#lines] = lines[#lines]:sub(1, end_col)
  
  local selection = table.concat(lines, "\n")
  
  -- Add buffer information
  local buf_info = M.get_current_buffer_info()
  local buffer_context = string.format(
    "# Selected Content\nFile: %s\nFiletype: %s\nSelection: Lines %d-%d\n\n```%s\n%s\n```",
    buf_info.path,
    buf_info.filetype,
    start_line,
    end_line,
    buf_info.filetype,
    selection
  )
  
  return buffer_context
end

function M.get_full_buffer_content()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")
  
  -- Add buffer information
  local buf_info = M.get_current_buffer_info()
  local buffer_context = string.format(
    "# Full Buffer Content\nFile: %s\nFiletype: %s\nLines: %d\n\n```%s\n%s\n```",
    buf_info.path,
    buf_info.filetype,
    buf_info.line_count,
    buf_info.filetype,
    content
  )
  
  return buffer_context
end

function M.get_intelligent_buffer_context(options)
  options = options or {}
  
  -- Check if there's a visual selection
  local has_selection = vim.fn.mode():match("[vV\22]") or
                        (vim.fn.exists("*nvim_buf_get_mark") and 
                        vim.fn.nvim_buf_get_mark(0, "<")[1] ~= 0)
  
  if has_selection then
    return M.get_current_selection()
  end
  
  -- Try to get function context with treesitter
  local ok, ts_integration = pcall(require, "ai-assistant.integrations.treesitter")
  if ok and options.smart_context ~= false then
    local smart_content = ts_integration.smart_select()
    if smart_content then
      local buf_info = M.get_current_buffer_info()
      return string.format(
        "# Smart Context\nFile: %s\nFiletype: %s\n\n```%s\n%s\n```",
        buf_info.path,
        buf_info.filetype,
        buf_info.filetype,
        smart_content
      )
    end
  end
  
  -- Default to context around cursor
  local window_size = options.window_size or 50
  return M.extract_context_around_cursor(window_size)
end

return M
