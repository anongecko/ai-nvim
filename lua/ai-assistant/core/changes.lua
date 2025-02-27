local utils = require("ai-assistant.utils")
local log = utils.log

local M = {
  _history = {},
  _current_index = 0,
}

local function compute_diff(old_text, new_text)
  -- Simple line-by-line diff
  local old_lines = vim.split(old_text, "\n")
  local new_lines = vim.split(new_text, "\n")
  
  local edits = {}
  local max_len = math.max(#old_lines, #new_lines)
  
  for i = 1, max_len do
    local old_line = old_lines[i] or ""
    local new_line = new_lines[i] or ""
    
    if old_line ~= new_line then
      table.insert(edits, {
        range = {
          start = { line = i - 1, character = 0 },
          ["end"] = { line = i - 1, character = #old_line }
        },
        newText = new_line
      })
    end
  end
  
  -- If the new text has fewer lines, add a delete edit for the remaining lines
  if #new_lines < #old_lines then
    table.insert(edits, {
      range = {
        start = { line = #new_lines, character = 0 },
        ["end"] = { line = #old_lines, character = 0 }
      },
      newText = ""
    })
  end
  
  return edits
end

function M.create_change(description, old_text, new_text, bufnr)
  local change = {
    id = utils.uuid(),
    timestamp = os.time(),
    description = description,
    old_text = old_text,
    new_text = new_text,
    bufnr = bufnr,
    edits = compute_diff(old_text, new_text)
  }
  
  -- Add to history, truncating if necessary
  while #M._history > M._current_index do
    table.remove(M._history)
  end
  
  table.insert(M._history, change)
  M._current_index = M._current_index + 1
  
  -- Keep a reasonable history size
  if #M._history > 100 then
    table.remove(M._history, 1)
    M._current_index = M._current_index - 1
  end
  
  return change
end

function M.apply_change(change, preview_only)
  if not change then
    log.error("No change to apply")
    return false
  end
  
  local bufnr = change.bufnr or vim.api.nvim_get_current_buf()
  
  if not vim.api.nvim_buf_is_valid(bufnr) then
    log.error("Invalid buffer for change application")
    return false
  end
  
  if preview_only then
    -- For preview, we apply the change to a temporary buffer and return the content
    local temp_bufnr = utils.create_scratch_buffer()
    local old_content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    vim.api.nvim_buf_set_lines(temp_bufnr, 0, -1, false, old_content)
    
    -- Apply edits to temp buffer
    utils.apply_text_edits(change.edits, temp_bufnr)
    
    -- Get content
    local new_content = vim.api.nvim_buf_get_lines(temp_bufnr, 0, -1, false)
    
    -- Clean up
    vim.api.nvim_buf_delete(temp_bufnr, { force = true })
    
    return new_content
  else
    -- For actual application, apply directly to the target buffer
    utils.apply_text_edits(change.edits, bufnr)
    return true
  end
end

function M.undo()
  if M._current_index <= 1 then
    log.warn("No changes to undo")
    return false
  end
  
  M._current_index = M._current_index - 1
  local change = M._history[M._current_index]
  
  if not change then
    log.error("No change found for undo")
    return false
  end
  
  -- Apply the original text
  local bufnr = change.bufnr or vim.api.nvim_get_current_buf()
  
  if not vim.api.nvim_buf_is_valid(bufnr) then
    log.error("Invalid buffer for undo")
    return false
  end
  
  vim.api.nvim_buf_set_text(
    bufnr,
    0, 0,
    vim.api.nvim_buf_line_count(bufnr), 0,
    vim.split(change.old_text, "\n")
  )
  
  return true
end

function M.redo()
  if M._current_index >= #M._history then
    log.warn("No changes to redo")
    return false
  end
  
  M._current_index = M._current_index + 1
  local change = M._history[M._current_index]
  
  if not change then
    log.error("No change found for redo")
    return false
  end
  
  -- Apply the new text
  local bufnr = change.bufnr or vim.api.nvim_get_current_buf()
  
  if not vim.api.nvim_buf_is_valid(bufnr) then
    log.error("Invalid buffer for redo")
    return false
  end
  
  vim.api.nvim_buf_set_text(
    bufnr,
    0, 0,
    vim.api.nvim_buf_line_count(bufnr), 0,
    vim.split(change.new_text, "\n")
  )
  
  return true
end

function M.get_history()
  return M._history
end

function M.clear_history()
  M._history = {}
  M._current_index = 0
  return true
end

function M.get_change(change_id)
  for _, change in ipairs(M._history) do
    if change.id == change_id then
      return change
    end
  end
  
  return nil
end

function M.format_diff(old_text, new_text)
  local old_lines = vim.split(old_text, "\n")
  local new_lines = vim.split(new_text, "\n")
  
  local diff_lines = {}
  local max_len = math.max(#old_lines, #new_lines)
  
  for i = 1, max_len do
    local old_line = old_lines[i] or ""
    local new_line = new_lines[i] or ""
    
    if old_line ~= new_line then
      if old_line ~= "" then
        table.insert(diff_lines, "- " .. old_line)
      end
      if new_line ~= "" then
        table.insert(diff_lines, "+ " .. new_line)
      end
    else
      table.insert(diff_lines, "  " .. old_line)
    end
  end
  
  return table.concat(diff_lines, "\n")
end

return M
