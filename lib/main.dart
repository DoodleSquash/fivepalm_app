import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(
    MaterialApp(
      title: 'Hotel Bell App',
      home: TcpClientPage(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class TcpClientPage extends StatefulWidget {
  @override
  _TcpClientPageState createState() => _TcpClientPageState();
}

class _TcpClientPageState extends State<TcpClientPage> {
  final ipController = TextEditingController();
  final portController = TextEditingController();

  Socket? socket;
  bool isConnected = false;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    final status = await Permission.notification.status;
    print('🔔 Notification permission status: $status');
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'server_channel',
            'Server Messages',
            channelDescription: 'Channel for server messages',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
          );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );
      await flutterLocalNotificationsPlugin.show(
        0,
        title,
        body,
        platformChannelSpecifics,
        payload: 'server_payload',
      );
      print('🔔 Notification shown: $title - $body');
    } catch (e) {
      print('❌ Notification error: $e');
    }
  }

  void connectToServer() async {
    final ip = ipController.text.trim();
    final port = int.tryParse(portController.text.trim()) ?? 0;

    try {
      socket = await Socket.connect(ip, port);
      setState(() => isConnected = true);
      print('✅ Connected to $ip:$port');

      socket!.listen(
        (data) {
          final response = String.fromCharCodes(data).trim();
          print("📩 Server: '$response'");
          if (response.isNotEmpty) {
            try {
              final jsonMsg = json.decode(response);
              final tableNo = jsonMsg['table_no'];
              if (tableNo != null) {
                _showNotification('Table Call', 'Table No: $tableNo');
              } else {
                _showNotification('Table Call', 'Table number not found');
              }
            } catch (e) {
              print('❌ JSON parse error: $e');
              _showNotification('Table Call', 'Invalid data received');
            }
          } else {
            print("⚠️ Received empty message, not showing notification.");
          }
        },
        onDone: () {
          print("🔌 Disconnected");
          setState(() => isConnected = false);
        },
        onError: (err) {
          print("❌ Error: $err");
          setState(() => isConnected = false);
        },
      );
    } catch (e) {
      print("🚫 Could not connect: $e");
    }
  }

  @override
  void dispose() {
    socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Hotel Bell App")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: ipController,
              decoration: InputDecoration(labelText: "Server IP"),
            ),
            TextField(
              controller: portController,
              decoration: InputDecoration(labelText: "Port"),
            ),
            ElevatedButton(onPressed: connectToServer, child: Text("Connect")),
            SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  color: isConnected ? Colors.green : Colors.grey,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(isConnected ? "Connected" : "Not Connected"),
              ],
            ),
            SizedBox(height: 20),
            // Test Notification button removed as per user request
          ],
        ),
      ),
    );
  }
}
