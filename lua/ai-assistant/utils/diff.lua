local M = {}

function M.compute_line_diff(old_lines, new_lines)
  local diff = {}
  
  local max_len = math.max(#old_lines, #new_lines)
  
  for i = 1, max_len do
    local old_line = old_lines[i] or ""
    local new_line = new_lines[i] or ""
    
    if old_line ~= new_line then
      table.insert(diff, {
        line = i - 1,
        old = old_line,
        new = new_line,
        type = old_line == "" and "add" or new_line == "" and "delete" or "change"
      })
    end
  end
  
  return diff
end

function M.compute_text_edits(old_text, new_text)
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

function M.colorize_diff(diff_text)
  local colored_lines = {}
  
  for _, line in ipairs(vim.split(diff_text, "\n")) do
    if line:sub(1, 1) == "+" then
      table.insert(colored_lines, "\27[32m" .. line .. "\27[0m") -- Green for additions
    elseif line:sub(1, 1) == "-" then
      table.insert(colored_lines, "\27[31m" .. line .. "\27[0m") -- Red for deletions
    else
      table.insert(colored_lines, line)
    end
  end
  
  return table.concat(colored_lines, "\n")
end

-- Compute character-level diff for a line
function M.compute_char_diff(old_line, new_line)
  -- Simple character diff
  local i = 1
  
  -- Find common prefix
  while i <= #old_line and i <= #new_line and old_line:sub(i, i) == new_line:sub(i, i) do
    i = i + 1
  end
  
  local prefix_len = i - 1
  
  -- Find common suffix
  local j = 0
  while j < #old_line - prefix_len and j < #new_line - prefix_len and
        old_line:sub(#old_line - j, #old_line - j) == new_line:sub(#new_line - j, #new_line - j) do
    j = j + 1
  end
  
  local suffix_pos_old = #old_line - j + 1
  local suffix_pos_new = #new_line - j + 1
  
  return {
    prefix_len = prefix_len,
    suffix_pos_old = suffix_pos_old,
    suffix_pos_new = suffix_pos_new,
    old_middle = old_line:sub(prefix_len + 1, suffix_pos_old - 1),
    new_middle = new_line:sub(prefix_len + 1, suffix_pos_new - 1)
  }
end

return M
