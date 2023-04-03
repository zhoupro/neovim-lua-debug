
-- dap -> server -> mobdebug

local clientCmd

function server()
    -- load namespace
    local socket = require("socket")
    -- create a TCP socket and bind it to the local host, at any port
    local server = assert(socket.bind("*", 9999))
    -- find out which port the OS chose for us
    local ip, port = server:getsockname()
    -- print a message informing what's up
    print("Please telnet to localhost on port " .. port)
    -- loop forever waiting for clients
    while true do
      -- wait for a connection from any client
      while true do
          local client = server:accept()
          -- make sure we don't block waiting for this client's line
          client:settimeout(1000)
         -- receive the line
          while true do
              local line, err = client:receive()
              -- if there was no error, send it back to the client
              if not err then
                  print(line)
                  handler(line)
                  -- local ret = rec(line)
                  -- client:send(ret .. "\n")
              else
                  client:close()
                  break
              end
          end
     end
    end
end

function handler(line)
    print("aa"..line)
end


function client()
    local host, port = "127.0.0.1", 8173
    local socket = require("socket")
    local tcp = assert(socket.tcp())

    tcp:connect(host, port);
    return function (x)
        while true do
            tcp:send(clientCmd .. "\n");
            local s, status, partial = tcp:receive()
            send(s)
            if status == "closed" then break end
        end
        tcp:close()
    end

end


local co = coroutine.create(client())

function rec(x)
    clientCmd = x
    status, value = coroutine.resume(co, x)
    return value
end

function send(s)
    coroutine.yield(s)
end

server()
