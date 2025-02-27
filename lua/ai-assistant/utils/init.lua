local M = {}

M.log = require("ai-assistant.utils.log")
M.path = require("ai-assistant.utils.path")
M.fs = require("ai-assistant.utils.fs")
M.json = require("ai-assistant.utils.json")
M.async = require("ai-assistant.utils.async")

function M.uuid()
  math.randomseed(os.time())
  local random = math.random
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
    return string.format("%x", v)
  end)
end

function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]
  
  -- Handle block selection
  if vim.fn.visualmode() == "\22" then
    local lines = {}
    for i = start_line, end_line do
      local line = vim.fn.getline(i):sub(start_col, end_col)
      table.insert(lines, line)
    end
    return lines
  else
    local lines = vim.fn.getline(start_line, end_line)
    if #lines == 0 then return "" end
    
    lines[1] = lines[1]:sub(start_col)
    lines[#lines] = lines[#lines]:sub(1, end_col)
    
    return table.concat(lines, "\n")
  end
end

function M.get_current_line()
  return vim.api.nvim_get_current_line()
end

function M.get_word_under_cursor()
  return vim.fn.expand("<cword>")
end

function M.get_current_buffer_content()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  return table.concat(lines, "\n")
end

function M.apply_text_edits(edits, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  -- Sort edits in reverse order to avoid position shifts
  table.sort(edits, function(a, b)
    if a.range.start.line ~= b.range.start.line then
      return a.range.start.line > b.range.start.line
    end
    return a.range.start.character > b.range.start.character
  end)
  
  vim.api.nvim_buf_set_option(bufnr, "undolevels", vim.api.nvim_buf_get_option(bufnr, "undolevels"))
  
  for _, edit in ipairs(edits) do
    local start_row = edit.range.start.line
    local start_col = edit.range.start.character
    local end_row = edit.range["end"].line
    local end_col = edit.range["end"].character
    
    local lines = vim.split(edit.newText, "\n")
    vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, lines)
  end
end

function M.tbl_deep_extend(behavior, ...)
  if vim.tbl_deep_extend then
    return vim.tbl_deep_extend(behavior, ...)
  end
  
  local result = {}
  local args = {...}
  
  for i = 1, #args do
    for k, v in pairs(args[i]) do
      if type(v) == "table" and type(result[k]) == "table" then
        result[k] = M.tbl_deep_extend(behavior, result[k], v)
      elseif behavior == "force" or result[k] == nil then
        result[k] = v
      end
    end
  end
  
  return result
end

function M.escape_pattern(s)
  return (s:gsub("([^%w])", "%%%1"))
end

function M.create_scratch_buffer(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_create_buf(false, true)
  
  for k, v in pairs(opts) do
    vim.api.nvim_buf_set_option(bufnr, k, v)
  end
  
  return bufnr
end

return M
