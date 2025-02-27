local M = {}
local uv = vim.loop or vim.uv
local sep = package.config:sub(1, 1)

function M.join(...)
  local result = table.concat({...}, sep):gsub(sep .. "+", sep)
  return result
end

function M.dirname(path)
  if not path then return nil end
  local last_sep = path:match(".*" .. sep)
  if last_sep then return last_sep:sub(1, -2) end
  return "."
end

function M.basename(path)
  if not path then return nil end
  local name = path:match("[^" .. sep .. "]+$")
  return name or ""
end

function M.exists(path)
  if not path then return false end
  return uv.fs_stat(path) ~= nil
end

function M.is_dir(path)
  if not path then return false end
  local stat = uv.fs_stat(path)
  return stat and stat.type == "directory" or false
end

function M.is_file(path)
  if not path then return false end
  local stat = uv.fs_stat(path)
  return stat and stat.type == "file" or false
end

function M.find_git_root(start_path)
  if not start_path or start_path == "" then
    start_path = uv.cwd()
  end
  
  local current = start_path
  for _ = 1, 20 do -- Limit directory traversal depth
    local git_dir = M.join(current, ".git")
    if M.is_dir(git_dir) then
      return current
    end
    
    local parent = M.dirname(current)
    if parent == current then break end
    current = parent
  end
  
  return nil
end

function M.normalize(path)
  if not path then return nil end
  path = path:gsub("[\\/]+", sep)
  return path
end

function M.relative(path, root)
  if not path or not root then return path end
  path = M.normalize(path)
  root = M.normalize(root)
  
  if path:sub(1, #root) == root then
    local rel = path:sub(#root + 1)
    return rel:gsub("^" .. sep, "")
  end
  return path
end

function M.home()
  return uv.os_homedir()
end

function M.tmp_dir()
  return os.getenv("TMPDIR") or os.getenv("TEMP") or "/tmp"
end

return M
