import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/perkembangan.dart';
import '../models/prediksi.dart';
import '../models/kontrol.dart';
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

  // Data state — setiap section punya loading independen
  List<Perkembangan>? _perkembanganData;
  List<Prediksi>? _prediksiData;
  Kontrol? _kontrolData;
  bool _isLoadingPerkembangan = true;
  bool _isLoadingPrediksi = true;
  bool _isLoadingKontrol = true;
  String? _errorMessage;

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

    _loadAllData();

    initNotifications();

    requestNotificationPermission();

    getFcmToken();
  }

  // Memuat semua API secara paralel — masing-masing update UI saat selesai
  Future<void> _loadAllData() async {
    _loadPerkembangan();
    _loadPrediksi();
    _loadKontrol();
  }

  Future<void> _loadPerkembangan() async {
    try {
      final data = await api.getPerkembangan();
      if (mounted) {
        setState(() {
          _perkembanganData = data;
          _isLoadingPerkembangan = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPerkembangan = false;
          if (_perkembanganData == null) {
            _errorMessage = getErrorMessage(e);
          }
        });
      }
    }
  }

  Future<void> _loadPrediksi() async {
    try {
      final data = await api.getPrediksi();
      if (mounted) {
        setState(() {
          _prediksiData = data;
          _isLoadingPrediksi = false;
        });

        // Cek notifikasi setelah data prediksi dimuat
        if (data.isNotEmpty) {
          checkWateringNotification(data.last.decision);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPrediksi = false;
        });
      }
    }
  }

  Future<void> _loadKontrol() async {
    try {
      final data = await api.getKontrol();
      if (mounted) {
        setState(() {
          _kontrolData = data;
          _isLoadingKontrol = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingKontrol = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      _loadPerkembangan(),
      _loadPrediksi(),
      _loadKontrol(),
    ]);
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

      body: _buildBody(),

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

  Widget _buildBody() {
    // Error state — hanya ditampilkan jika tidak ada data sama sekali
    if (_errorMessage != null && _perkembanganData == null) {
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
                _errorMessage!,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoadingPerkembangan = true;
                    _isLoadingPrediksi = true;
                    _errorMessage = null;
                  });
                  _loadAllData();
                },

                icon: const Icon(Icons.refresh),

                label: const Text("Coba Lagi"),
              ),
            ],
          ),
        ),
      );
    }

    // UI progresif — tampilkan layout segera, isi data per-section
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            // Section 1: Sensor cards
            _buildSensorSection(),

            const SizedBox(height: 20),

            // Section 2: Filter chips
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

            // Section 3: Charts
            _buildChartsSection(),

            const SizedBox(height: 20),

            // Section 4: Decision tree
            _buildDecisionSection(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ========================
  // SECTION BUILDERS
  // ========================

  Widget _buildSensorSection() {
    final hasPerkembangan =
        _perkembanganData != null && _perkembanganData!.isNotEmpty;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: hasPerkembangan
                  ? SensorCard(
                      title: "Kelembapan\nTanah",
                      color: AppColors.soilBrown,
                      value: "${_perkembanganData!.last.kelembapanTanah} %",
                      icon: Icons.water_drop,
                    )
                  : _buildPlaceholderCard(),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: hasPerkembangan
                  ? SensorCard(
                      title: "Suhu",
                      color: AppColors.temperatureOrange,
                      value: "${_perkembanganData!.last.suhu} °C",
                      icon: Icons.thermostat,
                    )
                  : _buildPlaceholderCard(),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: hasPerkembangan
                  ? SensorCard(
                      title: "Kelembapan\nUdara",
                      color: AppColors.waterBlue,
                      value: "${_perkembanganData!.last.kelembapanUdara} %",
                      icon: Icons.air,
                    )
                  : _buildPlaceholderCard(),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildStatusPompaCard(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholderCard() {
    return Card(
      child: SizedBox(
        height: 135,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPompaCard() {
    // Masih loading semua data yang diperlukan
    final stillLoading = (_isLoadingPrediksi && _prediksiData == null) &&
                         (_isLoadingKontrol && _kontrolData == null);
    if (stillLoading) {
      return SensorCard(
        title: "Status\nPompa",
        color: Colors.grey,
        value: "...",
        icon: Icons.bolt,
      );
    }

    // Cek apakah pompa aktif: mode_manual ON atau prediksi = siram
    final isManualOn = _kontrolData?.modeManual == true;
    final isPrediksiSiram = _prediksiData != null &&
        _prediksiData!.isNotEmpty &&
        _prediksiData!.last.decision.toLowerCase() == "siram";

    final isPumpActive = isManualOn || isPrediksiSiram;
    final statusPompa = isPumpActive ? "Aktif" : "Mati";

    return SensorCard(
      title: "Status\nPompa",

      color: isPumpActive ? AppColors.primaryGreen : AppColors.dangerRed,

      value: statusPompa,

      icon: Icons.bolt,
    );
  }

  Widget _buildChartsSection() {
    if (_isLoadingPerkembangan) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                "Memuat grafik...",
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_perkembanganData == null || _perkembanganData!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
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
        ),
      );
    }

    return Column(
      children: [
        HumidityChart(data: _perkembanganData!, filter: selectedFilter),

        const SizedBox(height: 20),

        TemperatureChart(data: _perkembanganData!, filter: selectedFilter),
      ],
    );
  }

  Widget _buildDecisionSection() {
    if (_isLoadingPrediksi) {
      return const SizedBox.shrink();
    }

    if (_prediksiData == null || _prediksiData!.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),

          child: Text("Belum ada data prediksi"),
        ),
      );
    }

    if (_perkembanganData == null || _perkembanganData!.isEmpty) {
      return const SizedBox.shrink();
    }

    final latest = _perkembanganData!.last;
    final latestPrediksi = _prediksiData!.last;

    return DecisionTreeCard(
      tanah: latest.kelembapanTanah,
      udara: latest.kelembapanUdara,
      suhu: latest.suhu,
      decision: latestPrediksi.decision,
    );
  }
}
