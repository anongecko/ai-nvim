local utils = require("ai-assistant.utils")
local log = utils.log
local json = utils.json
local async = utils.async

local curl_present = vim.fn.executable("curl") == 1
local job = vim.fn.has("nvim-0.8") == 1 and require("plenary.job") or nil

local M = {
  active_requests = {},
}

function M.init(provider_config)
  M.config = provider_config
end

local function create_headers(config)
  return {
    "Content-Type: application/json",
    "X-API-Key: " .. config.api_key,
    "anthropic-version: 2023-06-01",
  }
end

local function build_payload(prompt, context, options)
  local messages = {}
  
  -- Add prompt as user message
  table.insert(messages, {
    role = "user",
    content = prompt
  })
  
  local payload = {
    model = options.model or M.config.api_model,
    messages = messages,
    max_tokens = options.max_tokens,
    temperature = options.temperature,
    stream = options.stream or true,
  }
  
  -- Add context as system message if provided
  if context and context ~= "" then
    payload.system = context
  end
  
  -- Add any additional parameters from config
  if M.config.params then
    for k, v in pairs(M.config.params) do
      if not payload[k] then
        payload[k] = v
      end
    end
  end
  
  return payload
end

local function handle_streaming_response(data, callback)
  if not data or data == "" then
    return false
  end
  
  -- Skip empty data or event lines
  if data:match("^event:") then
    return false
  end
  
  -- Skip non-data lines
  if not data:match("^data:") then
    return false
  end
  
  -- Extract JSON from "data: {...}"
  local json_str = data:sub(6) -- Remove "data: " prefix
  
  if json_str == "[DONE]" then
    callback({ finish_reason = "stop" })
    return true
  end
  
  local success, result = pcall(json.decode, json_str)
  if not success then
    log.debug("Failed to parse JSON: %s", json_str)
    return false
  end
  
  -- Extract content
  local content = result.delta and result.delta.text
  local finish_reason = result.stop_reason
  
  if finish_reason then
    callback({ finish_reason = finish_reason })
    return true
  end
  
  if content then
    callback({ content = content })
  end
  
  return false
end

function M.stream_response(request_id, prompt, context, options, callback)
  if not curl_present then
    error("curl is required for API requests")
  end
  
  local payload = build_payload(prompt, context, options)
  payload.stream = true
  
  local headers = create_headers(M.config)
  local endpoint = M.config.api_endpoint
  
  local is_done = false
  local buffer = ""
  
  M.active_requests[request_id] = {
    is_done = false,
    job = nil,
  }
  
  local cmd = {
    "curl",
    "--silent",
    "--no-buffer",
    "-X", "POST",
    endpoint,
  }
  
  -- Add headers
  for _, header in ipairs(headers) do
    table.insert(cmd, "-H")
    table.insert(cmd, header)
  end
  
  -- Add payload
  table.insert(cmd, "-d")
  table.insert(cmd, json.encode(payload))
  
  local process_chunk = function(err, chunk)
    if err then
      log.error("Error in stream: %s", err)
      callback({ error = err })
      is_done = true
      M.active_requests[request_id].is_done = true
      return
    end
    
    if not chunk then
      is_done = true
      M.active_requests[request_id].is_done = true
      return
    end
    
    buffer = buffer .. chunk
    
    -- Process complete lines
    local lines = {}
    local start_idx = 1
    
    for i = 1, #buffer do
      if buffer:sub(i, i) == "\n" then
        table.insert(lines, buffer:sub(start_idx, i - 1))
        start_idx = i + 1
      end
    end
    
    -- Update buffer to contain only the incomplete line
    buffer = buffer:sub(start_idx)
    
    -- Process each complete line
    for _, line in ipairs(lines) do
      if line:match("^data: ") then
        local done = handle_streaming_response(line, callback)
        if done then
          is_done = true
          M.active_requests[request_id].is_done = true
          break
        end
      end
    end
  end
  
  -- Different job handling based on available APIs
  if job then
    local streaming_job = job:new({
      command = cmd[1],
      args = { unpack(cmd, 2) },
      on_stdout = function(_, data)
        vim.schedule(function()
          process_chunk(nil, data)
        end)
      end,
      on_stderr = function(_, data)
        vim.schedule(function()
          if data and data ~= "" then
            log.error("Stream stderr: %s", data)
            callback({ error = data })
          end
        end)
      end,
      on_exit = function(_, code)
        vim.schedule(function()
          if code ~= 0 and not is_done then
            log.error("Stream exited with code: %d", code)
            callback({ error = "Process exited with code " .. code })
          end
          if not is_done then
            callback({ finish_reason = "stop" })
          end
          M.active_requests[request_id].is_done = true
        end)
      end,
    })
    
    M.active_requests[request_id].job = streaming_job
    streaming_job:start()
  else
    -- Fallback for older Neovim versions
    local handle
    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)
    
    handle = vim.loop.spawn("curl", {
      args = { unpack(cmd, 2) },
      stdio = { nil, stdout, stderr }
    }, function(code)
      vim.schedule(function()
        if code ~= 0 and not is_done then
          log.error("Stream exited with code: %d", code)
          callback({ error = "Process exited with code " .. code })
        end
        if not is_done then
          callback({ finish_reason = "stop" })
        end
        M.active_requests[request_id].is_done = true
        stdout:close()
        stderr:close()
        handle:close()
      end)
    end)
    
    stdout:read_start(function(err, data)
      vim.schedule(function()
        process_chunk(err, data)
      end)
    end)
    
    stderr:read_start(function(err, data)
      vim.schedule(function()
        if data and data ~= "" then
          log.error("Stream stderr: %s", data)
          callback({ error = data })
        end
      end)
    end)
    
    M.active_requests[request_id].handle = handle
  end
  
  return request_id
end

function M.complete(prompt, context, options)
  if not curl_present then
    error("curl is required for API requests")
  end
  
  local payload = build_payload(prompt, context, options)
  payload.stream = false
  
  local headers = create_headers(M.config)
  local endpoint = M.config.api_endpoint
  
  local cmd = {
    "curl",
    "--silent",
    "-X", "POST",
    endpoint,
  }
  
  -- Add headers
  for _, header in ipairs(headers) do
    table.insert(cmd, "-H")
    table.insert(cmd, header)
  end
  
  -- Add payload
  table.insert(cmd, "-d")
  table.insert(cmd, json.encode(payload))
  
  -- Synchronous request
  local output = vim.fn.system(cmd)
  local success, result = pcall(json.decode, output)
  
  if not success then
    log.error("Failed to parse API response: %s", output)
    return { error = "Failed to parse API response" }
  end
  
  if result.error then
    log.error("API error: %s", vim.inspect(result.error))
    return { error = result.error.message }
  end
  
  local content = result.content and result.content[1] and result.content[1].text
  local stop_reason = result.stop_reason
  
  if not content then
    log.error("No content in API response: %s", vim.inspect(result))
    return { error = "No content in API response" }
  end
  
  return {
    content = content,
    finish_reason = stop_reason,
    response = result
  }
end

function M.cancel(request_id)
  local request = M.active_requests[request_id]
  if not request then
    return false
  end
  
  if request.is_done then
    return true
  end
  
  if request.job then
    request.job:shutdown()
  elseif request.handle then
    request.handle:kill(15) -- SIGTERM
  end
  
  M.active_requests[request_id] = nil
  return true
end

function M.is_available()
  return M.config.api_key and M.config.api_key ~= "" and curl_present
end

return M
