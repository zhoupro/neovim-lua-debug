import socket



def server():
    HOST = "127.0.0.1"  # Standard loopback interface address (localhost)
    PORT = 8086  # Port to listen on (non-privileged ports are > 1023)

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((HOST, PORT))
        s.listen()
        while True:
            conn, addr = s.accept()
            with conn:
                print(f"Connected by {addr}")
                while True:
                    data = conn.recv(1024)
                    if not data:
                        break
                    conn.sendall(data)




def send(s,msg):
    s.sendall(b"step\n")
    data = s.recv(1024)
    return data



def netcat(host, port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((host, int(port)))
    s.shutdown(socket.SHUT_WR)
    content = "step\n"
    s.sendall(content.encode())
    s.close()

def client_sender(buffer):
    client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    try:
        client.connect(("127.0.0.1", 8173))
        import pdb;pdb.set_trace()

        if len(buffer):
            client.send(buffer)

        while True:
            recv_len = 1
            response = ''

            while recv_len:
                data = client.recv(4096)
                recv_len = len(data)
                response += data

                if recv_len < 4096:
                    break

            print(response)
            buffer = raw_input('')
            buffer += '\n'

            client.send(buffer)
    except:
        print ('Exception. Exiting')
        client.close()
   

client_sender("")
