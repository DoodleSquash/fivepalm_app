import socket

HOST = '192.168.0.109'  # Server IP
PORT = 4509

data = '{"mac_address":"AA:BB:CC:DD:EE:FF","call_status":1,"battery":"good","table_no":29}'

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.connect((HOST, PORT))
    s.sendall(data.encode())