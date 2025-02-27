local uv = vim.loop or vim.uv
local M = {}

function M.run(fn)
  local co = coroutine.create(fn)
  local success, result = coroutine.resume(co)
  if not success then
    error(result)
  end
end

function M.await(fn, ...)
  local co = coroutine.running()
  if not co then
    error("Cannot await outside of a coroutine")
  end

  local args = {...}
  local callback = function(...)
    coroutine.resume(co, ...)
  end

  fn(unpack(args, 1, table.maxn(args)), callback)
  return coroutine.yield()
end

function M.throttle(fn, ms)
  local timer = uv.new_timer()
  local running = false
  return function(...)
    if running then return end
    running = true
    local args = {...}
    timer:start(ms, 0, function()
      running = false
      vim.schedule(function()
        fn(unpack(args))
      end)
    end)
  end
end

function M.debounce(fn, ms)
  local timer = uv.new_timer()
  return function(...)
    if timer:is_active() then
      timer:stop()
    end
    local args = {...}
    timer:start(ms, 0, function()
      vim.schedule(function()
        fn(unpack(args))
      end)
    end)
  end
end

function M.wrap(fn)
  return function(...)
    local args = {...}
    local cb = table.remove(args)
    local success, result = pcall(fn, unpack(args))
    if success then
      cb(nil, result)
    else
      cb(result)
    end
  end
end

return M
