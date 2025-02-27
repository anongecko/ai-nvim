local uv = vim.loop or vim.uv
local path = require("ai-assistant.utils.path")
local M = {}

function M.read_file(file_path)
  local fd = uv.fs_open(file_path, "r", 438)
  if not fd then return nil, "Failed to open file: " .. file_path end
  
  local stat = uv.fs_fstat(fd)
  if not stat then
    uv.fs_close(fd)
    return nil, "Failed to stat file: " .. file_path
  end
  
  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  
  if not data then return nil, "Failed to read file: " .. file_path end
  return data
end

function M.write_file(file_path, data)
  local fd = uv.fs_open(file_path, "w", 438)
  if not fd then return false, "Failed to open file for writing: " .. file_path end
  
  local success = uv.fs_write(fd, data, 0)
  uv.fs_close(fd)
  
  if not success then return false, "Failed to write to file: " .. file_path end
  return true
end

function M.mkdir(dir_path)
  return uv.fs_mkdir(dir_path, 493) -- 0755 in octal
end

function M.mkdir_p(dir_path)
  if path.exists(dir_path) then return true end
  
  local segments = {}
  local current = dir_path
  
  while current and current ~= "" and not path.exists(current) do
    table.insert(segments, 1, path.basename(current))
    current = path.dirname(current)
  end
  
  if not current or current == "" then return false end
  
  local result = current
  for _, segment in ipairs(segments) do
    result = path.join(result, segment)
    local ok = M.mkdir(result)
    if not ok then return false end
  end
  
  return true
end

function M.rmdir(dir_path)
  return uv.fs_rmdir(dir_path)
end

function M.unlink(file_path)
  return uv.fs_unlink(file_path)
end

function M.scandir(dir_path)
  local handle = uv.fs_scandir(dir_path)
  if not handle then return nil end
  
  local files = {}
  while true do
    local name, type = uv.fs_scandir_next(handle)
    if not name then break end
    table.insert(files, { name = name, type = type })
  end
  
  return files
end

function M.readdir(dir_path)
  local entries = M.scandir(dir_path)
  if not entries then return nil end
  
  local files = {}
  for _, entry in ipairs(entries) do
    table.insert(files, entry.name)
  end
  
  return files
end

function M.glob(pattern, base_dir)
  base_dir = base_dir or uv.cwd()
  
  if vim.fn.executable("rg") == 1 then
    local result = vim.fn.systemlist(string.format("rg --files %s --glob '%s'", base_dir, pattern))
    return result
  elseif vim.fn.executable("find") == 1 then
    local result = vim.fn.systemlist(string.format("find %s -type f -name '%s'", base_dir, pattern))
    return result
  else
    -- Fallback to Lua-based solution for simple patterns
    local results = {}
    local handle
    local queue = {base_dir}
    
    while #queue > 0 do
      local dir = table.remove(queue, 1)
      local entries = M.scandir(dir)
      
      if entries then
        for _, entry in ipairs(entries) do
          local full_path = path.join(dir, entry.name)
          
          if entry.type == "directory" then
            table.insert(queue, full_path)
          elseif entry.type == "file" and entry.name:match(pattern) then
            table.insert(results, full_path)
          end
        end
      end
    end
    
    return results
  end
end

return M
