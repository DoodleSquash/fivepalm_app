import socket
import json

# Server IP and Port
SERVER_IP = '0.0.0.0'  # Accepts connections from any IP
SERVER_PORT = 4509    # Choose any free port

# Create a TCP socket
server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# Bind and listen
server_socket.bind((SERVER_IP, SERVER_PORT))
server_socket.listen(5)
print(f"🔔 Server is listening on {SERVER_IP}:{SERVER_PORT}")

stored_messages = []

while True:
    # Accept a connection
    client_socket, client_address = server_socket.accept()
    print(f"✅ Connected with {client_address}")

    while True:
        try:
            data = client_socket.recv(1024).decode()
            if not data:
                break
            if not data.strip():
                continue  # Ignore empty messages
            print(f"📨 Received: {data}")

            try:
                json_data = json.loads(data)
                stored_messages.append(json_data)
                print(f"✅ Stored JSON: {json_data}")
                # Forward the original JSON string to the client
                client_socket.sendall((data + "\n").encode())
            except json.JSONDecodeError:
                print("❌ Received data is not valid JSON")
                client_socket.sendall(b"Invalid JSON\n")

        except ConnectionResetError:
            print("❌ Connection closed by client")
            break

    client_socket.close()
    print(f"🔌 Disconnected from {client_address}")
