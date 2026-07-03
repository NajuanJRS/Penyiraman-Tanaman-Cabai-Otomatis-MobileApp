import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/perkembangan.dart';
import '../models/prediksi.dart';
import '../theme/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'history_page.dart';
import 'control_page.dart';

import '../widgets/sensor_card.dart';
import '../widgets/humidity_chart.dart';
import '../widgets/temperature_chart.dart';
import '../widgets/decision_tree_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService api = ApiService();

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  int currentIndex = 0;

  String selectedFilter = "1 Bulan";

  late Future<List<Perkembangan>> _perkembanganFuture;
  late Future<List<Prediksi>> _predicsiFuture;

  String getErrorMessage(dynamic error) {
    final text = error.toString().toLowerCase();

    if (text.contains("socketexception") ||
        text.contains("network is unreachable") ||
        text.contains("failed host lookup")) {
      return "Tidak ada koneksi internet";
    }

    if (text.contains("500") || text.contains("503")) {
      return "Server sedang bermasalah";
    }

    if (text.contains("404")) {
      return "Data tidak ditemukan";
    }

    return "Gagal memuat data dashboard";
  }

  Widget buildFilterChip(String value) {
    final selected = selectedFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = value;
        });
      },

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),

        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),

        decoration: BoxDecoration(
          color:
              selected
                  ? Colors.deepPurple.withValues(alpha: 0.15)
                  : Colors.white,

          border: Border.all(
            color: selected ? Colors.deepPurple : Colors.grey.shade300,

            width: 1.2,
          ),

          borderRadius: BorderRadius.circular(25),
        ),

        child: Text(
          value,

          style: TextStyle(
            fontWeight: FontWeight.w600,

            color: selected ? Colors.deepPurple : Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _loadData();

    initNotifications();

    requestNotificationPermission();

    getFcmToken();
  }

  void _loadData() {
    _perkembanganFuture = api.getPerkembangan();
    _predicsiFuture = api.getPrediksi();
  }

  void _refresh() {
    setState(() {
      _loadData();
    });
  }

  Future<void> _onRefresh() async {
    final perkembanganFuture = api.getPerkembangan();
    final predicsiFuture = api.getPrediksi();

    try {
      await Future.wait([perkembanganFuture, predicsiFuture]);
    } catch (_) {
      // Futures will contain the error, FutureBuilder will handle display
    }

    if (mounted) {
      setState(() {
        _perkembanganFuture = perkembanganFuture;
        _predicsiFuture = predicsiFuture;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return "Selamat Pagi \u{1F44B}";
    if (hour < 15) return "Selamat Siang \u{1F44B}";
    if (hour < 18) return "Selamat Sore \u{1F44B}";
    return "Selamat Malam \u{1F44B}";
  }

  Future<void> getFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await api.saveFcmToken(token);
      }
    } catch (e) {
      debugPrint("Gagal mendapatkan FCM token: $e");
    }
  }

  Future<void> requestNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();

    final asked = prefs.getBool("notification_permission_asked") ?? false;

    if (asked) {
      return;
    }

    await Permission.notification.request();

    await prefs.setBool("notification_permission_asked", true);
  }

  Future<void> initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await notifications.initialize(settings);
  }

  Future<void> showPlantNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'watering_channel',
          'Watering Alert',
          channelDescription: 'Notifikasi penyiraman tanaman',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await notifications.show(
      999,
      'Caba.IoT',
      'Tanaman memerlukan penyiraman. Periksa mode penyiraman dan status pompa pada aplikasi.',
      details,
    );
  }

  Future<void> checkWateringNotification(String decision) async {
    final prefs = await SharedPreferences.getInstance();

    final lastDecision = prefs.getString('last_decision');

    if (decision.toLowerCase() == 'siram' && lastDecision != 'siram') {
      await showPlantNotification();
    }

    await prefs.setString('last_decision', decision.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Home"),
        centerTitle: false,
      ),

      body: FutureBuilder<List<Perkembangan>>(
        future: _perkembanganFuture,

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    const Icon(Icons.cloud_off, size: 90, color: Colors.red),

                    const SizedBox(height: 20),

                    const Text(
                      "Gagal memuat dashboard",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      getErrorMessage(snapshot.error),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: () {
                        _refresh();
                      },

                      icon: const Icon(Icons.refresh),

                      label: const Text("Coba Lagi"),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sensors_off, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "Tidak ada data sensor",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Data sensor belum tersedia saat ini",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            );
          }

          final latest = snapshot.data!.last;

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primaryGreen,
            child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SensorCard(
                        title: "Kelembapan\nTanah",
                        color: AppColors.soilBrown,
                        value: "${latest.kelembapanTanah} %",
                        icon: Icons.water_drop,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: SensorCard(
                        title: "Suhu",
                        color: AppColors.temperatureOrange,
                        value: "${latest.suhu} °C",
                        icon: Icons.thermostat,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: SensorCard(
                        title: "Kelembapan\nUdara",
                        color: AppColors.waterBlue,
                        value: "${latest.kelembapanUdara} %",
                        icon: Icons.air,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: FutureBuilder<List<Prediksi>>(
                        future: _predicsiFuture,

                        builder: (context, prediksiSnapshot) {
                          if (!prediksiSnapshot.hasData) {
                            return SensorCard(
                              title: "Status\nPompa",
                              color: Colors.grey,
                              value: "...",
                              icon: Icons.bolt,
                            );
                          }

                          final latestPrediksi = prediksiSnapshot.data!.last;

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            checkWateringNotification(latestPrediksi.decision);
                          });

                          final isPumpActive =
                              latestPrediksi.decision.toLowerCase() == "siram";

                          final statusPompa = isPumpActive ? "Aktif" : "Mati";

                          return SensorCard(
                            title: "Status\nPompa",

                            color:
                                isPumpActive
                                    ? AppColors.primaryGreen
                                    : AppColors.dangerRed,

                            value: statusPompa,

                            icon: Icons.bolt,
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 50,

                  child: ListView(
                    scrollDirection: Axis.horizontal,

                    children: [
                      const SizedBox(width: 16),

                      buildFilterChip("1 Hari"),

                      const SizedBox(width: 8),

                      buildFilterChip("3 Hari"),

                      const SizedBox(width: 8),

                      buildFilterChip("1 Minggu"),

                      const SizedBox(width: 8),

                      buildFilterChip("2 Minggu"),

                      const SizedBox(width: 8),

                      buildFilterChip("3 Minggu"),

                      const SizedBox(width: 8),

                      buildFilterChip("1 Bulan"),

                      const SizedBox(width: 8),

                      buildFilterChip("Maks"),

                      const SizedBox(width: 16),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                HumidityChart(data: snapshot.data!, filter: selectedFilter),

                const SizedBox(height: 20),

                TemperatureChart(data: snapshot.data!, filter: selectedFilter),

                const SizedBox(height: 20),

                FutureBuilder<List<Prediksi>>(
                  future: _predicsiFuture,

                  builder: (context, prediksiSnapshot) {
                    if (prediksiSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (prediksiSnapshot.hasError) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),

                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 50,
                              ),

                              const SizedBox(height: 10),

                              const Text("Data prediksi tidak tersedia"),
                            ],
                          ),
                        ),
                      );
                    }

                    if (!prediksiSnapshot.hasData ||
                        prediksiSnapshot.data!.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),

                          child: Text("Belum ada data prediksi"),
                        ),
                      );
                    }

                    final latestPrediksi = prediksiSnapshot.data!.last;

                    return DecisionTreeCard(
                      tanah: latest.kelembapanTanah,
                      udara: latest.kelembapanUdara,
                      suhu: latest.suhu,
                      decision: latestPrediksi.decision,
                    );
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
            ),
          );
        },
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),

        child: NavigationBar(
          height: 62,
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            if (index == 0) {
              return;
            }

            if (index == 1) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ControlPage()),
              );
              return;
            }

            if (index == 2) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              );
              return;
            }
          },

          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: "Home"),
            NavigationDestination(icon: Icon(Icons.settings), label: "Kontrol"),
            NavigationDestination(icon: Icon(Icons.history), label: "Histori"),
          ],
        ),
      ),
    );
  }
}
