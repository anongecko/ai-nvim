local M = {}
local has_json, vim_json = pcall(require, "vim.json")

function M.encode(data)
  if has_json then
    return vim_json.encode(data)
  else
    local status, result = pcall(vim.fn.json_encode, data)
    if not status then
      error("Failed to encode JSON: " .. result)
    end
    return result
  end
end

function M.decode(str)
  if has_json then
    return vim_json.decode(str)
  else
    local status, result = pcall(vim.fn.json_decode, str)
    if not status then
      error("Failed to decode JSON: " .. result)
    end
    return result
  end
end

function M.read_file(file_path)
  local file = io.open(file_path, "r")
  if not file then
    return nil, "Failed to open JSON file: " .. file_path
  end
  
  local content = file:read("*a")
  file:close()
  
  if not content or content == "" then
    return nil, "JSON file is empty: " .. file_path
  end
  
  local status, result = pcall(M.decode, content)
  if not status then
    return nil, "Failed to parse JSON file: " .. file_path .. " (" .. result .. ")"
  end
  
  return result
end

function M.write_file(file_path, data)
  local content = M.encode(data)
  
  local file = io.open(file_path, "w")
  if not file then
    return false, "Failed to open JSON file for writing: " .. file_path
  end
  
  local success = file:write(content)
  file:close()
  
  if not success then
    return false, "Failed to write to JSON file: " .. file_path
  end
  
  return true
end

function M.pretty_print(data)
  local json_str = M.encode(data)
  
  -- Simple pretty print by adding newlines and indentation
  local result = ""
  local indent = 0
  local in_string = false
  
  for i = 1, #json_str do
    local char = json_str:sub(i, i)
    
    if char == '"' and json_str:sub(i-1, i-1) ~= "\\" then
      in_string = not in_string
    end
    
    if not in_string then
      if char == "{" or char == "[" then
        indent = indent + 2
        result = result .. char .. "\n" .. string.rep(" ", indent)
      elseif char == "}" or char == "]" then
        indent = indent - 2
        result = result .. "\n" .. string.rep(" ", indent) .. char
      elseif char == "," then
        result = result .. char .. "\n" .. string.rep(" ", indent)
      else
        result = result .. char
      end
    else
      result = result .. char
    end
  end
  
  return result
end

return M
