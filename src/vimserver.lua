local M = {}

function M.start_server(host, port)
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
          -- print( vim.inspect(decoded))

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
          while true do
            local msg
            do
              local len = read_header()
              msg = read_body(len.content_length)
            end
            local ret = vim.fn.json_encode(msg)
            sock:write(ret)
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
end




M.start_server("127.0.0.1", 8889)
