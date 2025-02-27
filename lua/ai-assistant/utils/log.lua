local M = {}
local levels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }
local colors = {
  DEBUG = "\27[34m",
  INFO = "\27[32m",
  WARN = "\27[33m",
  ERROR = "\27[31m",
}
local reset = "\27[0m"

M.level = levels.INFO
M.file = nil
M.namespace = "ai-assist"

function M.setup(opts)
  if opts.level then M.level = levels[opts.level:upper()] or M.level end
  if opts.file then M.file = opts.file end
  if opts.namespace then M.namespace = opts.namespace end
end

local function log(level, msg, ...)
  if levels[level] < M.level then return end
  local formatted = string.format("[%s][%s] %s", M.namespace, level, msg)
  if select("#", ...) > 0 then formatted = string.format(formatted, ...) end

  if M.file then
    local file = io.open(M.file, "a")
    if file then
      file:write(os.date("%Y-%m-%d %H:%M:%S ") .. formatted .. "\n")
      file:close()
    end
  end

  if vim and vim.notify then
    vim.schedule(function()
      vim.notify(formatted, vim.log.levels[level] or vim.log.levels.INFO)
    end)
  else
    print(colors[level] .. formatted .. reset)
  end
end

function M.debug(msg, ...) log("DEBUG", msg, ...) end
function M.info(msg, ...) log("INFO", msg, ...) end
function M.warn(msg, ...) log("WARN", msg, ...) end
function M.error(msg, ...) log("ERROR", msg, ...) end

return M
