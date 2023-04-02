local seq_id = 1

local nvim_server

local hook_address

local log_filename


-- for now, only accepts a single
-- connection
local client

local sendProxyDAP

local make_response

local make_event

local log

local M = {}

function sendProxyDAP(data)
  log(vim.inspect(data))
  M.sendDAP(data)
end

function make_response(request, response)
  local msg = {
    type = "response",
    seq = seq_id,
    request_seq = request.seq,
    success = true,
    command = request.command
  }
  seq_id = seq_id + 1
  return vim.tbl_extend('error', msg, response)
end

function make_event(event)
  local msg = {
    type = "event",
    seq = seq_id,
    event = event,
  }
  seq_id = seq_id + 1
  return msg
end

function M.launch(opts)
  vim.validate {
    opts = {opts, 't', true}
  }

  if opts then
    vim.validate {
      ["opts.host"] = {opts.host, "s", true},
      ["opts.port"] = {opts.port, "n", true},
    }
  end

  if opts then
    vim.validate {
      ["opts.config_file"] = {opts.config_file, "s", true},
    }
  end


  if opts and opts.log then
    log_filename = vim.fn.stdpath("data") .. "/osv.log"
  end

  local env = nil
  local args = {vim.v.progpath, '--embed', '--headless'}

  nvim_server = vim.fn.jobstart(args, {rpc = true, env = env})

  local mode = vim.fn.rpcrequest(nvim_server, "nvim_get_mode")
  assert(not mode.blocking, "Neovim is waiting for input at startup. Aborting.")

  if not hook_addres then
    hook_address = vim.fn.serverstart()
  end

  vim.fn.rpcrequest(nvim_server, 'nvim_exec_lua', [[debug_hook_conn_address = ...]], {hook_address})

  M.server_messages = {}

  local host = (opts and opts.host) or "127.0.0.1"
  local port = (opts and opts.port) or 0
  local server = vim.fn.rpcrequest(nvim_server, 'nvim_exec_lua', [[return require"osv".start_server(...)]], {host, port, opts and opts.log})

  print("Server started on port " .. server.port)
  -- vim.defer_fn(M.wait_attach, 0)

  return server
end

function log(str)
  if log_filename then
    local f = io.open(log_filename, "a")
    if f then
      f:write(str .. "\n")
      f:close()
    end
  end

  -- required for regression testing
  if debug_output then
    table.insert(debug_output, tostring(str))
  else
    -- print(str)
  end
end


function M.sendDAP(msg)
  local succ, encoded = pcall(vim.fn.json_encode, msg)

  if succ then
    local bin_msg = "Content-Length: " .. string.len(encoded) .. "\r\n\r\n" .. encoded

    client:write(bin_msg)
  else
    log(encoded)
  end
end

function M.start_server(host, port, do_log)
  if do_log then
    log_filename = vim.fn.stdpath("data") .. "/osv.log"
  end


    local handlers = {}
    local breakpoints = {}

    function handlers.attach(request)
       log("handlers.attach")
      sendProxyDAP(make_response(request, {}))
    end


    function handlers.continue(request)
      log("handlers.continue")

      sendProxyDAP(make_response(request, {}))
      log("breakpoint hit")
      local msg = make_event("stopped")
      msg.body = {
        reason = "breakpoint",
        threadId = 1
      }
      sendProxyDAP(msg)

    end

    function handlers.disconnect(request)
      log("handlers.disconnect")
      sendProxyDAP(make_response(request, {}))

      vim.wait(1000)
      if nvim_server then
        vim.fn.jobstop(nvim_server)
        nvim_server = nil
      end
    end

    function handlers.evaluate(request)
      log("handlers.evaluate")
      log(vim.inspect(request))
      local args = request.arguments
      if args.context == "repl" then
        local result_repl = { a = {1,2,3} }
        sendProxyDAP(make_response(request, {
          body = {
            result = vim.inspect(result_repl),
            variablesReference = 0,
          }
        }))
      end
    end

    function handlers.next(request)

      log("handlers.next")
      log("breakpoint hit")
      local msg = make_event("stopped")
      msg.body = {
        reason = "breakpoint",
        threadId = 1
      }
      sendProxyDAP(msg)

      sendProxyDAP(make_response(request, {}))
    end

    function handlers.pause(request)
      log("handlers.pause")
    end

    function handlers.scopes(request)
      local args = request.arguments
      sendProxyDAP(make_response(request,{
        body = {
          scopes = scopes,
        };
      }))

    end

    function handlers.setBreakpoints(request)

      log("handlers.setBreakpoints")
      local args = request.arguments
      for line, line_bps in pairs(breakpoints) do
        line_bps[vim.uri_from_fname(args.source.path:lower())] = nil
      end
      local results_bps = {}

      for _, bp in ipairs(args.breakpoints) do
        breakpoints[bp.line] = breakpoints[bp.line] or {}
        local line_bps = breakpoints[bp.line]
        line_bps[vim.uri_from_fname(args.source.path:lower())] = true
        table.insert(results_bps, { verified = true })
        -- log("Set breakpoint at line " .. bp.line .. " in " .. args.source.path)
      end
    
      sendProxyDAP(make_response(request, {
        body = {
          breakpoints = results_bps
        }
      }))

     log("breakpoint hit")
      local msg = make_event("stopped")
      msg.body = {
        reason = "breakpoint",
        threadId = 1
      }
      sendProxyDAP(msg)
      log("breakpoint hit done")


    end

    function handlers.setExceptionBreakpoints(request)
      local args = request.arguments

      -- For now just send back an empty 
      -- answer
      sendProxyDAP(make_response(request, {
        body = {
          breakpoints = {}
        }
      }))
    end

    function handlers.stackTrace(request)

     log("handlers.stackTrace")

     local  stack_frames = { 
        {
        column = 0,
        id = 3,
        line = 5,
        name = "main",
        source = {
          name = "@/home/vagrant/playground/github/MobDebug/src/hello.lua",
          path = "/home/vagrant/playground/github/MobDebug/src/hello.lua"
        }
      }
  }

      sendProxyDAP(make_response(request,{
        body = {
          stackFrames = stack_frames,
          totalFrames = #stack_frames,
        };
      }))

    end

    function handlers.stepIn(request)
      sendProxyDAP(make_response(request,{}))
      log("breakpoint hit")
      local msg = make_event("stopped")
      msg.body = {
        reason = "breakpoint",
        threadId = 1
      }
      sendProxyDAP(msg)
      log("breakpoint hit done")


    end

    function handlers.stepOut(request)
     
      sendProxyDAP(make_response(request, {}))
     log("breakpoint hit")
      local msg = make_event("stopped")
      msg.body = {
        reason = "breakpoint",
        threadId = 1
      }
      sendProxyDAP(msg)
      log("breakpoint hit done")


    end

    function handlers.threads(request)
      sendProxyDAP(make_response(request, {
        body = {
          threads = {
            {
              id = 1,
              name = "main"
            }
          }
        }
      }))
    end

    function handlers.variables(request)
      sendProxyDAP(make_response(request, {
        body = {
          variables = variables,
        }
      }))
    end


  local server = vim.loop.new_tcp()

  server:bind(host, port)

  server:listen(128, function(err)

    local sock = vim.loop.new_tcp()
    server:accept(sock)

    local tcp_data = ""


    client = sock

    local function read_body(length)
      while string.len(tcp_data) < length do
        coroutine.yield()
      end

      local body = string.sub(tcp_data, 1, length)
      local succ, decoded = pcall(vim.fn.json_decode, body)

      tcp_data = string.sub(tcp_data, length+1)


      return decoded
    end

    local function read_header()
      while not string.find(tcp_data, "\r\n\r\n") do
        coroutine.yield()
      end
      local content_length = string.match(tcp_data, "^Content%-Length: (%d+)")

      local _, sep = string.find(tcp_data, "\r\n\r\n")
      tcp_data = string.sub(tcp_data, sep+1)


      return {
        content_length = tonumber(content_length),
      }
    end

    local dap_read = coroutine.create(function()
      local msg
      do
        local len = read_header()
        msg = read_body(len.content_length)
      end

      M.sendDAP(make_response(msg, {
        body = {}
      }))

      M.sendDAP(make_event('initialized'))

      while true do
        local msg
        do
          local len = read_header()
          msg = read_body(len.content_length)
        end

        local f = handlers[msg.command]
        log(vim.inspect(msg))

        if f then
          f(msg)
        end

      end
    end)

    sock:read_start(vim.schedule_wrap(function(err, chunk)
      if chunk then
        tcp_data = tcp_data .. chunk
        coroutine.resume(dap_read)
      else
        sock:shutdown()
        sock:close()
      end
    end))

  end)

  print("Server started on " .. server:getsockname().port)

  return {
    host = host,
    port = server:getsockname().port
  }
end


return M
