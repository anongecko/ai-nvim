local has_ts, ts = pcall(require, "nvim-treesitter.ts_utils")
local has_parsers, parsers = pcall(require, "nvim-treesitter.parsers")
local utils = require("ai-assistant.utils")
local log = utils.log

local M = {}

function M.setup()
  if not has_ts or not has_parsers then
    log.error("nvim-treesitter is required for treesitter integration")
    return false
  end
  
  return true
end

function M.get_node_at_cursor()
  if not has_ts then return nil end
  
  local node = ts.get_node_at_cursor()
  if not node then return nil end
  
  return node
end

function M.get_current_function()
  if not has_ts then return nil end
  
  local node = ts.get_node_at_cursor()
  if not node then return nil end
  
  local current = node
  while current do
    local type = current:type()
    if type == "function_declaration" or 
       type == "method_declaration" or 
       type == "function_definition" or
       type == "function" or
       type == "function_item" or
       type == "method_definition" then
      return current
    end
    current = current:parent()
  end
  
  return nil
end

function M.get_current_class()
  if not has_ts then return nil end
  
  local node = ts.get_node_at_cursor()
  if not node then return nil end
  
  local current = node
  while current do
    local type = current:type()
    if type == "class_declaration" or 
       type == "class_definition" or
       type == "class" or
       type == "struct_item" or
       type == "class_item" then
      return current
    end
    current = current:parent()
  end
  
  return nil
end

function M.get_node_text(node)
  if not node then return nil end
  
  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = node:range()
  
  if start_row == end_row then
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
    return line:sub(start_col + 1, end_col)
  else
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
    if #lines == 0 then return "" end
    
    lines[1] = lines[1]:sub(start_col + 1)
    lines[#lines] = lines[#lines]:sub(1, end_col)
    
    return table.concat(lines, "\n")
  end
end

function M.get_current_function_text()
  local node = M.get_current_function()
  return M.get_node_text(node)
end

function M.get_current_class_text()
  local node = M.get_current_class()
  return M.get_node_text(node)
end

function M.smart_select()
  -- Try to select the most meaningful context: function, class, or current node
  local fn_node = M.get_current_function()
  local class_node = M.get_current_class()
  
  -- Prefer function unless class is smaller or cursor is at class definition
  if fn_node and class_node then
    local fn_start, _, fn_end, _ = fn_node:range()
    local class_start, _, class_end, _ = class_node:range()
    
    local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
    
    -- If cursor is closer to class definition than to function start, prefer class
    if math.abs(cursor_row - class_start) < math.abs(cursor_row - fn_start) then
      return M.get_node_text(class_node)
    else
      return M.get_node_text(fn_node)
    end
  elseif fn_node then
    return M.get_node_text(fn_node)
  elseif class_node then
    return M.get_node_text(class_node)
  else
    -- Fall back to current node or current line
    local node = M.get_node_at_cursor()
    if node then
      return M.get_node_text(node)
    else
      return vim.api.nvim_get_current_line()
    end
  end
end

function M.get_file_symbols()
  if not has_ts then return {} end
  
  local bufnr = vim.api.nvim_get_current_buf()
  local lang = parsers.get_buf_lang(bufnr)
  if not lang then return {} end
  
  local parser = parsers.get_parser(bufnr, lang)
  if not parser then return {} end
  
  local symbols = {}
  local root = parser:parse()[1]:root()
  
  local function collect_symbols(node, parent_name)
    local type = node:type()
    local is_symbol = false
    local symbol_type = ""
    local symbol_name = ""
    
    if type == "function_declaration" or type == "function_definition" or type == "function" then
      is_symbol = true
      symbol_type = "function"
      -- Extract name based on language
      if lang == "lua" then
        local name_node = node:child(1)
        if name_node then symbol_name = M.get_node_text(name_node) end
      elseif lang == "python" or lang == "javascript" or lang == "typescript" then
        local name_node = node:child(0)
        if name_node then symbol_name = M.get_node_text(name_node) end
      end
    elseif type == "class_declaration" or type == "class_definition" or type == "class" then
      is_symbol = true
      symbol_type = "class"
      -- Extract name based on language
      if lang == "python" or lang == "javascript" or lang == "typescript" then
        local name_node = node:child(0)
        if name_node then symbol_name = M.get_node_text(name_node) end
      end
    end
    
    if is_symbol and symbol_name ~= "" then
      local start_row, _, end_row, _ = node:range()
      table.insert(symbols, {
        name = symbol_name,
        type = symbol_type,
        parent = parent_name,
        range = { start = start_row, ["end"] = end_row },
        node = node
      })
      
      -- Process children with this as parent
      for child in node:iter_children() do
        collect_symbols(child, symbol_name)
      end
    else
      -- Process children with same parent
      for child in node:iter_children() do
        collect_symbols(child, parent_name)
      end
    end
  end
  
  collect_symbols(root, nil)
  return symbols
end

return M
