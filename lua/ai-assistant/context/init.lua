local utils = require("ai-assistant.utils")
local config = require("ai-assistant.config")
local path = utils.path
local fs = utils.fs
local log = utils.log

local M = {
  _cache = {},
  _project_roots = {},
}

local function is_excluded(file_path, exclusions)
  -- Check file patterns
  for _, pattern in ipairs(exclusions.file_patterns) do
    if file_path:match(pattern) then
      return true
    end
  end
  
  -- Check specific paths
  for _, excluded_path in ipairs(exclusions.paths) do
    if file_path:match(excluded_path .. "$") or file_path:match(excluded_path .. "/") then
      return true
    end
  end
  
  -- Check file size
  local stat = vim.loop.fs_stat(file_path)
  if stat and stat.size > exclusions.max_file_size then
    return true
  end
  
  return false
end

local function get_project_files(root_dir, exclusions, max_files)
  local files = {}
  
  -- Skip if project root is not valid
  if not root_dir or not path.is_dir(root_dir) then
    return files
  end
  
  -- Use ripgrep if available for better performance
  if vim.fn.executable("rg") == 1 then
    local cmd = string.format(
      "rg --files --hidden --no-ignore-vcs --glob '!.git' --glob '!node_modules' %s",
      root_dir
    )
    
    local output = vim.fn.systemlist(cmd)
    
    for _, file_path in ipairs(output) do
      if #files >= max_files then
        break
      end
      
      if not is_excluded(file_path, exclusions) then
        table.insert(files, file_path)
      end
    end
  else
    -- Fallback to recursive directory scan
    local function scan_dir(dir)
      if #files >= max_files then
        return
      end
      
      local entries = fs.scandir(dir)
      if not entries then return end
      
      for _, entry in ipairs(entries) do
        if #files >= max_files then
          break
        end
        
        local full_path = path.join(dir, entry.name)
        
        if not is_excluded(full_path, exclusions) then
          if entry.type == "file" then
            table.insert(files, full_path)
          elseif entry.type == "directory" then
            scan_dir(full_path)
          end
        end
      end
    end
    
    scan_dir(root_dir)
  end
  
  return files
end

local function get_file_content(file_path)
  local content = fs.read_file(file_path)
  if not content then
    log.warn("Failed to read file: %s", file_path)
    return nil
  end
  return content
end

local function extract_relevant_context(buffer_content, cursor_position, window_size)
  -- Simple window extraction around cursor
  local lines = vim.split(buffer_content, "\n")
  
  local start_line = math.max(1, cursor_position[1] - math.floor(window_size / 2))
  local end_line = math.min(#lines, cursor_position[1] + math.floor(window_size / 2))
  
  local context_lines = {}
  for i = start_line, end_line do
    table.insert(context_lines, lines[i])
  end
  
  return table.concat(context_lines, "\n")
end

function M.setup()
  local cfg = config.get()
  
  if not cfg.context.enable_project_context and not cfg.context.enable_buffer_context then
    log.warn("Both project and buffer context are disabled")
  end
  
  -- Clear cache on setup
  M._cache = {}
  M._project_roots = {}
  
  return true
end

function M.get_project_root(buf_path)
  buf_path = buf_path or vim.api.nvim_buf_get_name(0)
  
  if not buf_path or buf_path == "" then
    return nil
  end
  
  -- Check cache first
  if M._project_roots[buf_path] then
    return M._project_roots[buf_path]
  end
  
  -- Find git root
  local root = path.find_git_root(buf_path)
  
  if root then
    M._project_roots[buf_path] = root
    return root
  end
  
  -- Fallback to directory of file
  local dir = path.dirname(buf_path)
  if dir and dir ~= "" then
    M._project_roots[buf_path] = dir
    return dir
  end
  
  return nil
end

function M.build_project_context(options)
  local cfg = config.get()
  if not cfg.context.enable_project_context then
    return ""
  end
  
  options = options or {}
  local root_dir = options.root_dir or M.get_project_root()
  
  if not root_dir then
    log.debug("No project root found for context")
    return ""
  end
  
  -- Check cache
  local cache_key = root_dir .. ":project"
  if M._cache[cache_key] then
    return M._cache[cache_key]
  end
  
  -- Get project files
  local files = get_project_files(
    root_dir,
    cfg.context.exclusions,
    options.max_files or cfg.context.max_files
  )
  
  if #files == 0 then
    log.debug("No files found for project context")
    return ""
  end
  
  -- Build context
  local context_parts = {}
  
  table.insert(context_parts, "# Project Context\n")
  table.insert(context_parts, string.format("Project root: %s\n", root_dir))
  
  -- Sort files by relevance (currently just alphabetical)
  table.sort(files)
  
  for _, file_path in ipairs(files) do
    local rel_path = path.relative(file_path, root_dir)
    local content = get_file_content(file_path)
    
    if content then
      table.insert(context_parts, string.format("\n## File: %s\n", rel_path))
      table.insert(context_parts, "```")
      table.insert(context_parts, content)
      table.insert(context_parts, "```\n")
    end
  end
  
  local context = table.concat(context_parts, "\n")
  
  -- Cache the result
  M._cache[cache_key] = context
  
  return context
end

function M.build_buffer_context(options)
  local cfg = config.get()
  if not cfg.context.enable_buffer_context then
    return ""
  end
  
  options = options or {}
  local bufnr = options.bufnr or 0
  
  local buffer_path = vim.api.nvim_buf_get_name(bufnr)
  if buffer_path == "" then
    log.debug("No buffer path for context")
    return ""
  end
  
  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local buffer_content = table.concat(lines, "\n")
  
  -- Get cursor position
  local cursor_position = options.cursor_position or vim.api.nvim_win_get_cursor(0)
  
  -- Extract relevant context around cursor
  local window_size = options.window_size or 50 -- Number of lines around cursor
  local relevant_content = extract_relevant_context(buffer_content, cursor_position, window_size)
  
  -- Build context
  local context_parts = {}
  
  table.insert(context_parts, "# Buffer Context\n")
  table.insert(context_parts, string.format("File: %s\n", buffer_path))
  
  table.insert(context_parts, string.format("\n## Current buffer (around line %d):\n", cursor_position[1]))
  table.insert(context_parts, "```")
  table.insert(context_parts, relevant_content)
  table.insert(context_parts, "```\n")
  
  return table.concat(context_parts, "\n")
end

function M.build_context(options)
  options = options or {}
  
  local project_context = options.include_project ~= false and M.build_project_context(options) or ""
  local buffer_context = options.include_buffer ~= false and M.build_buffer_context(options) or ""
  
  local context_parts = {}
  
  if project_context ~= "" then
    table.insert(context_parts, project_context)
  end
  
  if buffer_context ~= "" then
    table.insert(context_parts, buffer_context)
  end
  
  return table.concat(context_parts, "\n\n")
end

function M.clear_cache()
  M._cache = {}
end

return M
