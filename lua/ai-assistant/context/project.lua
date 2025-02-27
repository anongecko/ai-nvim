local utils = require("ai-assistant.utils")
local config = require("ai-assistant.config")
local exclusions = require("ai-assistant.context.exclusions")
local log = utils.log
local path = utils.path
local fs = utils.fs

local M = {
  _project_cache = {},
  _file_cache = {},
}

function M.detect_project_root(start_path)
  start_path = start_path or vim.api.nvim_buf_get_name(0)
  
  if start_path == "" then
    start_path = vim.fn.getcwd()
  end
  
  -- Check cache first
  if M._project_cache[start_path] then
    return M._project_cache[start_path]
  end
  
  -- Try git root
  local git_root = path.find_git_root(start_path)
  if git_root then
    M._project_cache[start_path] = git_root
    return git_root
  end
  
  -- Look for common project files
  local current = path.is_file(start_path) and path.dirname(start_path) or start_path
  
  local project_indicators = {
    "package.json", -- Node.js
    "Cargo.toml",   -- Rust
    "go.mod",       -- Go
    "pom.xml",      -- Maven (Java)
    "build.gradle", -- Gradle (Java)
    "Makefile",     -- C/C++
    "CMakeLists.txt", -- CMake projects
    "requirements.txt", -- Python
    "setup.py",     -- Python
    "pyproject.toml", -- Python
    "composer.json", -- PHP
    "Gemfile",      -- Ruby
    ".project",     -- Eclipse
    ".idea",        -- IntelliJ
    ".vscode",      -- VS Code
  }
  
  for _ = 1, 20 do -- Limit directory traversal depth
    for _, indicator in ipairs(project_indicators) do
      local indicator_path = path.join(current, indicator)
      if path.exists(indicator_path) then
        M._project_cache[start_path] = current
        return current
      end
    end
    
    local parent = path.dirname(current)
    if parent == current then break end
    current = parent
  end
  
  -- Fallback to current directory
  local cwd = vim.fn.getcwd()
  M._project_cache[start_path] = cwd
  return cwd
end

function M.get_project_files(root_dir, opts)
  root_dir = root_dir or M.detect_project_root()
  opts = opts or {}
  
  if not root_dir or not path.is_dir(root_dir) then
    log.warn("Invalid project root: %s", root_dir)
    return {}
  end
  
  -- Check cache
  local cache_key = root_dir .. ":" .. (opts.max_files or "")
  if M._file_cache[cache_key] then
    return M._file_cache[cache_key]
  end
  
  local cfg = config.get()
  local max_files = opts.max_files or cfg.context.max_files or 10
  local files = {}
  
  -- Use ripgrep if available for better performance
  if vim.fn.executable("rg") == 1 then
    local cmd = string.format(
      "rg --files --hidden --no-ignore-vcs --glob '!.git' %s",
      root_dir
    )
    
    local output = vim.fn.systemlist(cmd)
    
    for _, file_path in ipairs(output) do
      if #files >= max_files then
        break
      end
      
      if exclusions.should_include_file(file_path, cfg.context.exclusions) then
        table.insert(files, file_path)
      end
    end
  else
    -- Fallback to recursive directory scan
    local function scan_dir(dir, results)
      if #results >= max_files then
        return
      end
      
      local entries = fs.scandir(dir)
      if not entries then return end
      
      for _, entry in ipairs(entries) do
        if #results >= max_files then
          break
        end
        
        local full_path = path.join(dir, entry.name)
        
        if not exclusions.is_excluded(full_path, cfg.context.exclusions) then
          if entry.type == "file" then
            if not exclusions.is_binary_file(full_path) then
              table.insert(results, full_path)
            end
          elseif entry.type == "directory" then
            scan_dir(full_path, results)
          end
        end
      end
    end
    
    scan_dir(root_dir, files)
  end
  
  -- Sort files by relevance (for now just alphabetical)
  table.sort(files)
  
  -- Cache the result
  M._file_cache[cache_key] = files
  
  return files
end

function M.get_project_structure(root_dir, max_depth)
  root_dir = root_dir or M.detect_project_root()
  max_depth = max_depth or 3
  
  if not root_dir or not path.is_dir(root_dir) then
    log.warn("Invalid project root: %s", root_dir)
    return ""
  end
  
  local function build_tree(dir, prefix, depth)
    if depth > max_depth then
      return ""
    end
    
    local entries = fs.scandir(dir)
    if not entries then return "" end
    
    local lines = {}
    local dirs = {}
    local files = {}
    
    for _, entry in ipairs(entries) do
      local name = entry.name
      
      -- Skip hidden and excluded files/dirs
      if not name:match("^%.") or name == ".github" or name == ".vscode" then
        local full_path = path.join(dir, name)
        if not exclusions.is_excluded(full_path) then
          if entry.type == "directory" then
            table.insert(dirs, name)
          else
            table.insert(files, name)
          end
        end
      end
    end
    
    table.sort(dirs)
    table.sort(files)
    
    for _, name in ipairs(dirs) do
      table.insert(lines, prefix .. "└── " .. name .. "/")
      local nested = build_tree(path.join(dir, name), prefix .. "    ", depth + 1)
      if nested ~= "" then
        table.insert(lines, nested)
      end
    end
    
    -- Limit the number of files shown
    local max_files = 10
    if #files > max_files then
      for i = 1, max_files do
        table.insert(lines, prefix .. "├── " .. files[i])
      end
      table.insert(lines, prefix .. "├── ... (" .. (#files - max_files) .. " more files)")
    else
      for i, name in ipairs(files) do
        local connector = i == #files and "└── " or "├── "
        table.insert(lines, prefix .. connector .. name)
      end
    end
    
    return table.concat(lines, "\n")
  end
  
  local root_name = path.basename(root_dir)
  local tree = root_name .. "/"
  local structure = build_tree(root_dir, "", 1)
  
  if structure ~= "" then
    tree = tree .. "\n" .. structure
  end
  
  return tree
end

function M.get_project_summary(root_dir)
  root_dir = root_dir or M.detect_project_root()
  
  if not root_dir or not path.is_dir(root_dir) then
    log.warn("Invalid project root: %s", root_dir)
    return "No valid project found."
  end
  
  -- Get project name
  local project_name = path.basename(root_dir)
  
  -- Try to get project type and version from package.json, Cargo.toml, etc.
  local project_type = "Unknown"
  local project_version = "Unknown"
  local project_description = ""
  
  local project_files = {
    ["package.json"] = function(content)
      local data = utils.json.decode(content)
      return {
        type = "Node.js",
        version = data.version,
        description = data.description
      }
    end,
    ["Cargo.toml"] = function(content)
      -- Simple TOML parsing
      local version = content:match('version%s*=%s*"([^"]+)"')
      local description = content:match('description%s*=%s*"([^"]+)"')
      return {
        type = "Rust",
        version = version,
        description = description
      }
    end,
    ["go.mod"] = function(content)
      local mod_name = content:match("module%s+([^\n]+)")
      return {
        type = "Go",
        version = "",
        description = mod_name
      }
    end,
    ["pom.xml"] = function(content)
      local version = content:match("<version>([^<]+)</version>")
      local artifact_id = content:match("<artifactId>([^<]+)</artifactId>")
      return {
        type = "Java (Maven)",
        version = version,
        description = artifact_id
      }
    end,
    ["requirements.txt"] = function(_)
      return {
        type = "Python",
        version = "",
        description = ""
      }
    end,
    ["Gemfile"] = function(_)
      return {
        type = "Ruby",
        version = "",
        description = ""
      }
    end,
    ["composer.json"] = function(content)
      local data = utils.json.decode(content)
      return {
        type = "PHP",
        version = data.version,
        description = data.description
      }
    end,
  }
  
  for file_name, parser in pairs(project_files) do
    local file_path = path.join(root_dir, file_name)
    if path.exists(file_path) then
      local content = fs.read_file(file_path)
      if content then
        local info = parser(content)
        project_type = info.type
        project_version = info.version or "Unknown"
        project_description = info.description or ""
        break
      end
    end
  end
  
  -- Get file count statistics
  local file_stats = {}
  local total_files = 0
  
  if vim.fn.executable("find") == 1 then
    -- Get language stats using find
    local find_output = vim.fn.systemlist("find " .. root_dir .. " -type f -not -path '*/\\.*' | grep -E '\\.(js|py|rs|go|java|rb|php|ts|c|cpp|h|hpp|css|html|md)$' | sed 's/.*\\.//g' | sort | uniq -c | sort -nr")
    
    for _, line in ipairs(find_output) do
      local count, ext = line:match("%s*(%d+)%s+(%w+)")
      if count and ext then
        file_stats[ext] = tonumber(count)
        total_files = total_files + tonumber(count)
      end
    end
  end
  
  -- Format the summary
  local summary = string.format("# Project Summary\n\n"
    .. "- **Name**: %s\n"
    .. "- **Type**: %s\n"
    .. "- **Version**: %s\n",
    project_name, project_type, project_version)
  
  if project_description ~= "" then
    summary = summary .. string.format("- **Description**: %s\n", project_description)
  end
  
  if total_files > 0 then
    summary = summary .. "\n## File Statistics\n\n"
    for ext, count in pairs(file_stats) do
      summary = summary .. string.format("- %s: %d files\n", ext, count)
    end
  end
  
  -- Add structure
  summary = summary .. "\n## Project Structure\n\n```\n" .. M.get_project_structure(root_dir) .. "\n```\n"
  
  return summary
end

function M.build_project_context(root_dir, opts)
  root_dir = root_dir or M.detect_project_root()
  opts = opts or {}
  
  if not root_dir or not path.is_dir(root_dir) then
    log.warn("Invalid project root: %s", root_dir)
    return ""
  end
  
  local cfg = config.get()
  local max_files = opts.max_files or cfg.context.max_files
  
  -- Get project files
  local files = M.get_project_files(root_dir, { max_files = max_files })
  
  if #files == 0 then
    log.warn("No suitable files found in project: %s", root_dir)
    return ""
  end
  
  -- Build context
  local context_parts = {}
  
  table.insert(context_parts, "# Project Context\n")
  table.insert(context_parts, string.format("Project root: %s\n", root_dir))
  
  -- Add project summary
  local summary = M.get_project_summary(root_dir)
  table.insert(context_parts, summary)
  
  -- Add file contents
  table.insert(context_parts, "\n## Project Files\n")
  
  for _, file_path in ipairs(files) do
    local rel_path = path.relative(file_path, root_dir)
    local content = fs.read_file(file_path)
    
    if content then
      -- Try to determine filetype
      local ext = rel_path:match("%.([^%.]+)$")
      local filetype = ext
      
      table.insert(context_parts, string.format("\n### File: %s\n", rel_path))
      table.insert(context_parts, "```" .. (filetype or ""))
      table.insert(context_parts, content)
      table.insert(context_parts, "```\n")
    end
  end
  
  return table.concat(context_parts, "\n")
end

function M.clear_cache()
  M._project_cache = {}
  M._file_cache = {}
  log.debug("Project context cache cleared")
end

return M
