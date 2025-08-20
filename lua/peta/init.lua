-- HTTP Client Plugin for Neovim
-- File: lua/http-client/init.lua

local M = {}
local api = vim.api
local fn = vim.fn

-- Plugin state
local state = {
  requests = {},
  current_request = nil,
  buf = nil,
  win = nil,
  response_buf = nil,
  response_win = nil
}

-- Default request template
local default_request = {
  name = "New Request",
  method = "GET",
  url = "https://httpbin.org/get",
  headers = {},
  body = "",
  response = nil
}

-- Load requests from file
local function load_requests()
  local data_dir = fn.stdpath('data') .. '/http-client'
  local requests_file = data_dir .. '/requests.json'

  if fn.filereadable(requests_file) == 1 then
    local content = table.concat(fn.readfile(requests_file), '\n')
    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == 'table' then
      state.requests = data
      return
    end
  end

  -- Initialize with example requests if file doesn't exist
  state.requests = {
    {
      name = "GET Example",
      method = "GET",
      url = "https://httpbin.org/get",
      headers = {
        ["User-Agent"] = "Neovim HTTP Client"
      },
      body = ""
    },
    {
      name = "POST Example",
      method = "POST",
      url = "https://httpbin.org/post",
      headers = {
        ["Content-Type"] = "application/json"
      },
      body = '{"key": "value"}'
    }
  }
end

-- Save requests to file
local function save_requests()
  local data_dir = fn.stdpath('data') .. '/http-client'
  fn.mkdir(data_dir, 'p')
  local requests_file = data_dir .. '/requests.json'

  local content = vim.json.encode(state.requests)
  fn.writefile(vim.split(content, '\n'), requests_file)
end

-- Execute HTTP request using curl
local function execute_request(request)
  local cmd = { 'curl', '-s', '-i', '-X', request.method }

  -- Add headers
  for key, value in pairs(request.headers) do
    table.insert(cmd, '-H')
    table.insert(cmd, key .. ': ' .. value)
  end

  -- Add body for POST/PUT/PATCH requests
  if request.body and request.body ~= "" then
    table.insert(cmd, '-d')
    table.insert(cmd, request.body)
  end

  -- Add URL
  table.insert(cmd, request.url)

  -- Execute curl command
  local result = fn.system(cmd)

  -- Parse response
  local lines = vim.split(result, '\n')
  local headers_end = 1
  for i, line in ipairs(lines) do
    if line == "" then
      headers_end = i
      break
    end
  end

  local response_headers = table.concat(vim.list_slice(lines, 1, headers_end - 1), '\n')
  local response_body = table.concat(vim.list_slice(lines, headers_end + 1), '\n')

  return {
    headers = response_headers,
    body = response_body,
    full = result
  }
end

-- Create request list buffer content
local function create_request_list()
  local lines = {}
  table.insert(lines, "HTTP Client - Saved Requests")
  table.insert(lines, "===============================")
  table.insert(lines, "")

  for i, req in ipairs(state.requests) do
    table.insert(lines, string.format("%d. [%s] %s", i, req.method, req.name))
    table.insert(lines, string.format("   %s", req.url))
    table.insert(lines, "")
  end

  table.insert(lines, "")
  table.insert(lines, "Commands:")
  table.insert(lines, "  <Enter>  - Edit/Execute request")
  table.insert(lines, "  n        - New request")
  table.insert(lines, "  d        - Delete request")
  table.insert(lines, "  r        - Rename request")
  table.insert(lines, "  q        - Quit")

  return lines
end

-- Create request editor content
local function create_request_editor(request)
  local lines = {}

  table.insert(lines, "Request: " .. request.name)
  table.insert(lines, "================")
  table.insert(lines, "")
  table.insert(lines, "Method: " .. request.method)
  table.insert(lines, "URL: " .. request.url)
  table.insert(lines, "")
  table.insert(lines, "Headers:")
  for key, value in pairs(request.headers) do
    table.insert(lines, key .. ": " .. value)
  end
  table.insert(lines, "")
  table.insert(lines, "Body:")
  if request.body and request.body ~= "" then
    for _, line in ipairs(vim.split(request.body, '\n')) do
      table.insert(lines, line)
    end
  end
  table.insert(lines, "")
  table.insert(lines, "Commands:")
  table.insert(lines, "  <Enter>  - Execute request")
  table.insert(lines, "  e        - Edit request")
  table.insert(lines, "  s        - Save request")
  table.insert(lines, "  <Esc>    - Back to list")

  return lines
end

-- Show response in split window
local function show_response(response)
  -- Create response buffer if it doesn't exist
  if not state.response_buf or not api.nvim_buf_is_valid(state.response_buf) then
    state.response_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(state.response_buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(state.response_buf, 'filetype', 'http')
  end

  -- Set response content
  local lines = vim.split(response.full, '\n')
  api.nvim_buf_set_lines(state.response_buf, 0, -1, false, lines)

  -- Create or focus response window
  if not state.response_win or not api.nvim_win_is_valid(state.response_win) then
    vim.cmd('vsplit')
    state.response_win = api.nvim_get_current_win()
    api.nvim_win_set_buf(state.response_win, state.response_buf)
  else
    api.nvim_set_current_win(state.response_win)
  end

  -- Focus back to main window
  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_set_current_win(state.win)
  end
end

-- Handle keypress in request list
local function handle_list_keypress(key)
  if key == 'q' then
    M.close()
  elseif key == 'n' then
    -- Create new request
    local new_req = vim.deepcopy(default_request)
    new_req.name = "Request " .. (#state.requests + 1)
    table.insert(state.requests, new_req)
    save_requests()
    M.refresh()
  elseif key == 'd' then
    -- Delete current request
    local line = api.nvim_win_get_cursor(state.win)[1]
    local req_idx = math.floor((line - 3) / 3) + 1
    if req_idx > 0 and req_idx <= #state.requests then
      table.remove(state.requests, req_idx)
      save_requests()
      M.refresh()
    end
  elseif key == '\r' then -- Enter key
    -- Edit/Execute request
    local line = api.nvim_win_get_cursor(state.win)[1]
    local req_idx = math.floor((line - 3) / 3) + 1
    if req_idx > 0 and req_idx <= #state.requests then
      state.current_request = req_idx
      M.show_request_editor(state.requests[req_idx])
    end
  end
end

-- Handle keypress in request editor
local function handle_editor_keypress(key)
  if key == '\x1b' then   -- Escape key
    M.show_request_list()
  elseif key == '\r' then -- Enter key
    -- Execute request
    local request = state.requests[state.current_request]
    vim.notify("Executing request: " .. request.name)

    local response = execute_request(request)
    request.response = response
    show_response(response)

    vim.notify("Request completed!")
  elseif key == 'e' then
    -- Edit request (open in new buffer)
    M.edit_request(state.requests[state.current_request])
  elseif key == 's' then
    -- Save requests
    save_requests()
    vim.notify("Requests saved!")
  end
end

-- Set up keymaps for buffer
local function setup_keymaps(mode)
  local opts = { buffer = state.buf, silent = true, noremap = true }

  if mode == 'list' then
    api.nvim_buf_set_keymap(state.buf, 'n', 'q', '', {
      callback = function() handle_list_keypress('q') end,
      buffer = state.buf
    })
    api.nvim_buf_set_keymap(state.buf, 'n', 'n', '', {
      callback = function() handle_list_keypress('n') end,
      buffer = state.buf
    })
    api.nvim_buf_set_keymap(state.buf, 'n', 'd', '', {
      callback = function() handle_list_keypress('d') end,
      buffer = state.buf
    })
    api.nvim_buf_set_keymap(state.buf, 'n', '<CR>', '', {
      callback = function() handle_list_keypress('\r') end,
      buffer = state.buf
    })
  elseif mode == 'editor' then
    api.nvim_buf_set_keymap(state.buf, 'n', '<Esc>', '', {
      callback = function() handle_editor_keypress('\x1b') end,
      buffer = state.buf
    })
    api.nvim_buf_set_keymap(state.buf, 'n', '<CR>', '', {
      callback = function() handle_editor_keypress('\r') end,
      buffer = state.buf
    })
    api.nvim_buf_set_keymap(state.buf, 'n', 'e', '', {
      callback = function() handle_editor_keypress('e') end,
      buffer = state.buf
    })
    api.nvim_buf_set_keymap(state.buf, 'n', 's', '', {
      callback = function() handle_editor_keypress('s') end,
      buffer = state.buf
    })
  end
end

-- Create floating window
local function create_window()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create buffer if it doesn't exist
  if not state.buf or not api.nvim_buf_is_valid(state.buf) then
    state.buf = api.nvim_create_buf(false, true)
  end

  -- Set buffer options
  api.nvim_buf_set_option(state.buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(state.buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(state.buf, 'modifiable', false)

  -- Create window
  local opts = {
    style = 'minimal',
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = 'rounded',
    title = ' HTTP Client ',
    title_pos = 'center'
  }

  state.win = api.nvim_open_win(state.buf, true, opts)

  -- Set window options
  api.nvim_win_set_option(state.win, 'wrap', false)
  api.nvim_win_set_option(state.win, 'cursorline', true)
end

-- Show request list
function M.show_request_list()
  if not state.win or not api.nvim_win_is_valid(state.win) then
    create_window()
  end

  local lines = create_request_list()

  api.nvim_buf_set_option(state.buf, 'modifiable', true)
  api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  api.nvim_buf_set_option(state.buf, 'modifiable', false)

  setup_keymaps('list')
  api.nvim_win_set_cursor(state.win, { 4, 0 }) -- Position cursor on first request
end

-- Show request editor
function M.show_request_editor(request)
  if not state.win or not api.nvim_win_is_valid(state.win) then
    create_window()
  end

  local lines = create_request_editor(request)

  api.nvim_buf_set_option(state.buf, 'modifiable', true)
  api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  api.nvim_buf_set_option(state.buf, 'modifiable', false)

  setup_keymaps('editor')
end

-- Edit request in new buffer
function M.edit_request(request)
  local edit_buf = api.nvim_create_buf(true, false)

  -- Create editable request format
  local lines = {
    "# HTTP Request Editor",
    "# Save and close this buffer to update the request",
    "",
    "Name: " .. request.name,
    "Method: " .. request.method,
    "URL: " .. request.url,
    "",
    "# Headers (key: value format)",
  }

  for key, value in pairs(request.headers) do
    table.insert(lines, key .. ": " .. value)
  end

  table.insert(lines, "")
  table.insert(lines, "# Body")
  if request.body and request.body ~= "" then
    for _, line in ipairs(vim.split(request.body, '\n')) do
      table.insert(lines, line)
    end
  end

  api.nvim_buf_set_lines(edit_buf, 0, -1, false, lines)
  api.nvim_buf_set_option(edit_buf, 'filetype', 'yaml')

  -- Open in new window
  vim.cmd('split')
  api.nvim_win_set_buf(0, edit_buf)

  -- Set up save autocmd
  api.nvim_create_autocmd({ "BufWritePost" }, {
    buffer = edit_buf,
    callback = function()
      M.parse_and_update_request(edit_buf, request)
    end
  })
end

-- Parse edited request and update
function M.parse_and_update_request(buf, original_request)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local updated_request = vim.deepcopy(original_request)

  local in_body = false
  local body_lines = {}
  updated_request.headers = {}

  for _, line in ipairs(lines) do
    if line:match("^Name:%s*(.+)") then
      updated_request.name = line:match("^Name:%s*(.+)")
    elseif line:match("^Method:%s*(.+)") then
      updated_request.method = line:match("^Method:%s*(.+)")
    elseif line:match("^URL:%s*(.+)") then
      updated_request.url = line:match("^URL:%s*(.+)")
    elseif line:match("^#%s*Body") then
      in_body = true
    elseif in_body and not line:match("^#") then
      table.insert(body_lines, line)
    elseif line:match("^([^#][^:]+):%s*(.+)") and not in_body then
      local key, value = line:match("^([^:]+):%s*(.+)")
      if key and value then
        updated_request.headers[key] = value
      end
    end
  end

  updated_request.body = table.concat(body_lines, '\n')

  -- Update the request in the list
  state.requests[state.current_request] = updated_request
  save_requests()

  vim.notify("Request updated!")
end

-- Refresh current view
function M.refresh()
  if state.current_request then
    M.show_request_editor(state.requests[state.current_request])
  else
    M.show_request_list()
  end
end

-- Close plugin
function M.close()
  if state.response_win and api.nvim_win_is_valid(state.response_win) then
    api.nvim_win_close(state.response_win, true)
    state.response_win = nil
  end

  if state.win and api.nvim_win_is_valid(state.win) then
    api.nvim_win_close(state.win, true)
    state.win = nil
  end

  state.current_request = nil
end

-- Toggle plugin
function M.toggle()
  if state.win and api.nvim_win_is_valid(state.win) then
    M.close()
  else
    load_requests()
    M.show_request_list()
  end
end

-- Setup function
function M.setup(opts)
  opts = opts or {}

  -- Set up keymap to toggle plugin
  local keymap = opts.keymap or '<leader>hr'
  vim.keymap.set('n', keymap, M.toggle, { desc = 'Toggle HTTP Client' })

  -- Create user commands
  api.nvim_create_user_command('HttpClient', M.toggle, {})
  api.nvim_create_user_command('HttpClientOpen', function()
    load_requests()
    M.show_request_list()
  end, {})
  api.nvim_create_user_command('HttpClientClose', M.close, {})
end

return M
