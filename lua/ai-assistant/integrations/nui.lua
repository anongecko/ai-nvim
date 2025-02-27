local log = require("ai-assistant.utils.log")

local M = {
  _initialized = false,
  components = {}
}

function M.setup()
  local ok, nui = pcall(require, "nui.popup")
  if not ok then
    log.debug("nui.nvim is not available")
    return false
  end
  
  M._initialized = true
  
  -- Load NUI components
  M.popup = require("nui.popup")
  M.split = require("nui.split")
  M.layout = require("nui.layout")
  M.menu = require("nui.menu")
  M.input = require("nui.input")
  M.text = require("nui.text")
  M.tree = require("nui.tree")
  M.line = require("nui.line")
  
  return true
end

function M.create_popup(options)
  if not M._initialized then
    log.error("nui.nvim integration is not initialized")
    return nil
  end
  
  options = options or {}
  
  local popup = M.popup(options)
  return popup
end

function M.create_split(options)
  if not M._initialized then
    log.error("nui.nvim integration is not initialized")
    return nil
  end
  
  options = options or {}
  
  local split = M.split(options)
  return split
end

function M.create_layout(layout_options)
  if not M._initialized then
    log.error("nui.nvim integration is not initialized")
    return nil
  end
  
  local layout = M.layout(layout_options)
  return layout
end

function M.create_menu(options)
  if not M._initialized then
    log.error("nui.nvim integration is not initialized")
    return nil
  end
  
  options = options or {}
  
  local menu = M.menu(options)
  return menu
end

function M.create_input(options, on_submit)
  if not M._initialized then
    log.error("nui.nvim integration is not initialized")
    return nil
  end
  
  options = options or {}
  
  local input = M.input(options, on_submit)
  return input
end

function M.create_tree(options)
  if not M._initialized then
    log.error("nui.nvim integration is not initialized")
    return nil
  end
  
  options = options or {}
  
  local tree = M.tree(options)
  return tree
end

function M.create_line(content)
  if not M._initialized then
    log.error("nui.nvim integration is not initialized")
    return nil
  end
  
  local line = M.line(content)
  return line
end

-- Create a panel with input and output areas
function M.create_panel(options)
  if not M._initialized then
    log.error("nui.nvim integration is not initialized")
    return nil
  end
  
  options = options or {}
  local width = options.width or math.floor(vim.o.columns * 0.8)
  local height = options.height or math.floor(vim.o.lines * 0.8)
  local position = options.position or "50%"
  local input_height = options.input_height or 5
  local output_height = height - input_height - 3 -- Account for borders
  
  -- Create layout with output (top) and input (bottom)
  local layout = M.layout(
    {
      position = position,
      size = {
        width = width,
        height = height,
      },
      relative = "editor",
    },
    M.layout.Box({
      M.layout.Box(M.popup({
        border = {
          style = "rounded",
          text = {
            top = options.output_title or " Output ",
            top_align = "center",
          },
        },
        buf_options = {
          modifiable = true,
          readonly = false,
        },
        win_options = {
          wrap = true,
          linebreak = true,
          cursorline = true,
        },
      }), { size = output_height }),
      M.layout.Box(M.popup({
        border = {
          style = "rounded",
          text = {
            top = options.input_title or " Input ",
            top_align = "center",
          },
        },
        buf_options = {
          modifiable = true,
          readonly = false,
        },
        win_options = {
          wrap = true,
          linebreak = true,
        },
      }), { size = input_height }),
    }, { dir = "col" })
  )
  
  -- Mount the layout
  layout:mount()
  
  -- Extract components
  local output = layout.box.box[1].popup
  local input = layout.box.box[2].popup
  
  -- Set up keymaps
  vim.api.nvim_buf_set_keymap(input.bufnr, "n", "<Esc>", "", {
    noremap = true,
    callback = function()
      layout:unmount()
      if options.on_close then
        options.on_close()
      end
    end
  })
  
  vim.api.nvim_buf_set_keymap(output.bufnr, "n", "<Esc>", "", {
    noremap = true,
    callback = function()
      layout:unmount()
      if options.on_close then
        options.on_close()
      end
    end
  })
  
  -- Setup submit action
  vim.api.nvim_buf_set_keymap(input.bufnr, "i", "<C-CR>", "", {
    noremap = true,
    callback = function()
      if options.on_submit then
        local lines = vim.api.nvim_buf_get_lines(input.bufnr, 0, -1, false)
        local content = table.concat(lines, "\n")
        options.on_submit(content, input, output)
      end
    end
  })
  
  vim.api.nvim_buf_set_keymap(input.bufnr, "n", "<C-CR>", "", {
    noremap = true,
    callback = function()
      if options.on_submit then
        local lines = vim.api.nvim_buf_get_lines(input.bufnr, 0, -1, false)
        local content = table.concat(lines, "\n")
        options.on_submit(content, input, output)
      end
    end
  })
  
  return {
    layout = layout,
    output = output,
    input = input,
    unmount = function()
      layout:unmount()
    end
  }
end

return M
