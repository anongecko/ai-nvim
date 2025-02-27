local utils = require("ai-assistant.utils")
local config = require("ai-assistant.config")
local log = utils.log
local path = utils.path

local M = {}

-- Default exclusion patterns 
M.default_file_patterns = {
  "%.git/",
  "node_modules/",
  "%.cache/",
  "%.vscode/",
  "%.idea/",
  "%.DS_Store",
  "%.png$",
  "%.jpg$",
  "%.jpeg$",
  "%.gif$",
  "%.svg$",
  "%.pdf$",
  "%.zip$",
  "%.gz$",
  "%.tar$",
  "%.rar$",
  "%.7z$",
  "%.mp3$",
  "%.mp4$",
  "%.mov$",
  "%.o$",
  "%.a$",
  "%.so$",
  "%.dylib$",
  "%.dll$",
  "%.exe$",
  "%.pyc$",
  "%.class$",
  "%.min%.js$",
  "%.bundle%.js$",
  "%.min%.css$",
  "%.lock$",
  "yarn%.lock$",
  "package%-lock%.json$",
  "Cargo%.lock$",
  "Gemfile%.lock$",
}

-- Default exclusion paths
M.default_paths = {
  "dist",
  "build",
  "out",
  "target",
  "venv",
  ".env",
  "bin",
  "obj",
  ".next",
  ".nuxt",
  ".output",
  "coverage",
  "vendor",
  "tmp",
  "log",
  "logs",
}

function M.is_excluded(file_path, exclusions)
  exclusions = exclusions or config.get().context.exclusions
  
  -- Check file patterns
  for _, pattern in ipairs(exclusions.file_patterns) do
    if file_path:match(pattern) then
      log.debug("Excluded file by pattern '%s': %s", pattern, file_path)
      return true, "pattern:" .. pattern
    end
  end
  
  -- Check specific paths
  for _, excluded_path in ipairs(exclusions.paths) do
    if file_path:match(excluded_path .. "$") or file_path:match(excluded_path .. "/") then
      log.debug("Excluded file by path '%s': %s", excluded_path, file_path)
      return true, "path:" .. excluded_path
    end
  end
  
  -- Check file size if the file exists
  if path.exists(file_path) and path.is_file(file_path) then
    local stat = vim.loop.fs_stat(file_path)
    if stat and stat.size > exclusions.max_file_size then
      log.debug("Excluded file by size (%d > %d): %s", stat.size, exclusions.max_file_size, file_path)
      return true, "size:" .. stat.size
    end
  end
  
  -- Check file extension against built-in binary formats
  local binary_extensions = {
    ".obj", ".bin", ".dat", ".db", ".sqlite", ".sqlite3", ".mdb", ".iso", ".raw",
    ".img", ".ico", ".icns", ".psd", ".tiff", ".ttf", ".otf", ".woff", ".woff2",
    ".eot", ".bin", ".exe", ".dll", ".so", ".a", ".o", ".sys", ".lib", ".bmp",
    ".class", ".pyc", ".pyo", ".luac", ".rbc"
  }
  
  for _, ext in ipairs(binary_extensions) do
    if file_path:match(ext .. "$") then
      log.debug("Excluded file by binary extension '%s': %s", ext, file_path)
      return true, "binary_extension:" .. ext
    end
  end
  
  return false
end

function M.is_binary_file(file_path)
  if not path.exists(file_path) or not path.is_file(file_path) then
    return false
  end
  
  local file = io.open(file_path, "rb")
  if not file then
    return false
  end
  
  -- Read the first 8KB of the file to check for binary content
  local bytes = file:read(8192)
  file:close()
  
  if not bytes then
    return false
  end
  
  -- Check for null bytes, which are common in binary files
  if bytes:find('\0') then
    return true
  end
  
  -- Check if the file is mostly non-printable characters
  local non_printable = 0
  for i = 1, #bytes do
    local byte = bytes:sub(i, i):byte()
    if byte < 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then
      non_printable = non_printable + 1
    end
  end
  
  return non_printable / #bytes > 0.3 -- If more than 30% non-printable, consider binary
end

function M.should_include_file(file_path, exclusions)
  if M.is_excluded(file_path, exclusions) then
    return false
  end
  
  if M.is_binary_file(file_path) then
    log.debug("Excluded binary file: %s", file_path)
    return false
  end
  
  return true
end

function M.filter_files(files, exclusions)
  local filtered = {}
  for _, file in ipairs(files) do
    if M.should_include_file(file, exclusions) then
      table.insert(filtered, file)
    end
  end
  
  return filtered
end

function M.get_gitignore_patterns(root_dir)
  if not root_dir or not path.exists(root_dir) then
    return {}
  end
  
  local gitignore_path = path.join(root_dir, ".gitignore")
  if not path.exists(gitignore_path) then
    return {}
  end
  
  local content = utils.fs.read_file(gitignore_path)
  if not content then
    return {}
  end
  
  local patterns = {}
  for line in content:gmatch("[^\r\n]+") do
    -- Skip comments and empty lines
    if not line:match("^%s*#") and line:match("%S") then
      -- Convert gitignore pattern to Lua pattern
      local pattern = line:gsub("^%s+", ""):gsub("%s+$", "") -- Trim
      
      -- Skip negated patterns
      if not pattern:match("^!") then
        -- Convert basic gitignore glob syntax to Lua patterns
        pattern = pattern:gsub("%-", "%%-")  -- Escape hyphens
        pattern = pattern:gsub("%.", "%%.")  -- Escape dots
        pattern = pattern:gsub("%*%*", ".*") -- ** -> .*
        pattern = pattern:gsub("%*", "[^/]*") -- * -> [^/]*
        pattern = pattern:gsub("%?", ".") -- ? -> .
        
        -- Handle directory patterns
        if pattern:match("/$") then
          pattern = pattern .. ".*"
        else
          -- Match both file and directory
          pattern = pattern .. "$"
        end
        
        table.insert(patterns, pattern)
      end
    end
  end
  
  return patterns
end

function M.setup()
  local cfg = config.get()
  
  -- Ensure default exclusions are included
  for _, pattern in ipairs(M.default_file_patterns) do
    if not vim.tbl_contains(cfg.context.exclusions.file_patterns, pattern) then
      table.insert(cfg.context.exclusions.file_patterns, pattern)
    end
  end
  
  for _, excluded_path in ipairs(M.default_paths) do
    if not vim.tbl_contains(cfg.context.exclusions.paths, excluded_path) then
      table.insert(cfg.context.exclusions.paths, excluded_path)
    end
  end
  
  log.debug("Exclusions setup complete with %d patterns and %d paths", 
    #cfg.context.exclusions.file_patterns, 
    #cfg.context.exclusions.paths)
  
  return true
end

return M
