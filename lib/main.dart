import 'dart:convert';
import 'dart:io';
import 'dart:async';
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
  const TcpClientPage({super.key});

  @override
  _TcpClientPageState createState() => _TcpClientPageState();
}


class Message {
  final int tableNo;
  final DateTime receivedAt;
  Message({required this.tableNo, required this.receivedAt});
}

int _findMessageIndex(List<Message> messages, int tableNo) {
  return messages.indexWhere((msg) => msg.tableNo == tableNo);
}

class _TcpClientPageState extends State<TcpClientPage> {
  final ipController = TextEditingController();
  final portController = TextEditingController();

  Socket? socket;
  bool isConnected = false;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final List<Message> messages = [];

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
              final callStatus = jsonMsg['call_status'];
              if (tableNo != null && callStatus != null) {
                setState(() {
                  final idx = _findMessageIndex(messages, tableNo);
                  if (callStatus == 1) {
                    if (idx == -1) {
                      messages.insert(0, Message(tableNo: tableNo, receivedAt: DateTime.now()));
                      _showNotification('Table Call', 'Table No: $tableNo');
                    } else {
                      // Update timestamp if a new call comes for the same table
                      messages[idx] = Message(tableNo: tableNo, receivedAt: DateTime.now());
                    }
                  } else if (callStatus == 0) {
                    if (idx != -1) {
                      messages.removeAt(idx);
                    }
                  }
                });
              } else {
                _showNotification('Table Call', 'Table number or call status not found');
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
            // Home button at bottom right
            Expanded(child: Container()),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0, right: 8.0),
                child: FloatingActionButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => HomePage(messages: messages)),
                    );
                    setState(() {}); // This will rebuild after returning from Home
                  },
                  child: Icon(Icons.home),
                  tooltip: 'Home',
                ),
              ),
            ),
          ],
        ),
      ),
    );

  }

}

class HomePage extends StatefulWidget {
  final List<Message> messages;
  const HomePage({super.key, required this.messages});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update UI every 30 seconds for 'minutes ago' text
    _timer = Timer.periodic(Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes == 0) {
      return 'Just now';
    } else if (diff.inMinutes == 1) {
      return '1 minute ago';
    } else {
      return '${diff.inMinutes} minutes ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    return Scaffold(
      appBar: AppBar(title: Text('Table Calls')),
      body: messages.isEmpty
          ? Center(child: Text('No table calls yet.'))
          : ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return ListTile(
                  leading: Icon(Icons.table_bar),
                  title: Text('Table No: ${msg.tableNo}'),
                  subtitle: Text(timeAgo(msg.receivedAt)),
                );
              },
            ),
    );
  }
}

