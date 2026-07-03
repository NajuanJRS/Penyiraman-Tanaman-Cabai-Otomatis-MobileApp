import 'package:flutter/material.dart';
import 'dart:async';

import '../models/kontrol.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'history_page.dart';
import 'dashboard_page.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  final ApiService api = ApiService();
  late Future<Kontrol> kontrolFuture;
  String? errorMessage;

  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    kontrolFuture = api.getKontrol();
    refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }

  Future<void> refresh() async {
    if (!mounted) return;

    setState(() {
      errorMessage = null;
      kontrolFuture = api.getKontrol();
    });
  }

  Future<bool> showConfirmDialog({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Batal"),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Ya"),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

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

    if (text.startsWith("exception: ")) {
      return error.toString().substring("Exception: ".length);
    }

    return "Gagal memuat data kontrol";
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> toggleOtomatis(bool currentState) async {
    final aktifkan = !currentState;

    final confirm = await showConfirmDialog(
      title: "Konfirmasi",
      message: aktifkan ? "Aktifkan Mode Otomatis?" : "Matikan Mode Otomatis?",
    );

    if (!confirm) return;
    try {
      await api.updateKontrol(id: 1, modeManual: false, modeOtomatis: aktifkan);

      if (!mounted) return;
      showSuccess(
        aktifkan
            ? "Mode Otomatis berhasil diaktifkan"
            : "Mode Otomatis berhasil dinonaktifkan",
      );

      refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,

          content: Text(getErrorMessage(e)),
        ),
      );
    }
  }

  Future<void> toggleManual(bool currentState) async {
    final aktifkan = !currentState;

    final confirm = await showConfirmDialog(
      title: "Konfirmasi",
      message: aktifkan ? "Aktifkan Mode Manual?" : "Matikan Mode Manual?",
    );

    if (!confirm) return;
    try {
      await api.updateKontrol(id: 1, modeManual: aktifkan, modeOtomatis: false);

      if (!mounted) return;
      showSuccess(
        aktifkan
            ? "Mode Manual berhasil diaktifkan"
            : "Mode Manual berhasil dinonaktifkan",
      );

      refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,

          content: Text(getErrorMessage(e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Kontrol"),
        centerTitle: false,
      ),

      body: FutureBuilder<Kontrol>(
        future: kontrolFuture,

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    const Icon(
                      Icons.settings_ethernet,
                      size: 90,
                      color: Colors.red,
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Gagal memuat data kontrol",
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
                        refresh();
                      },

                      icon: const Icon(Icons.refresh),

                      label: const Text("Coba Lagi"),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final kontrol = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              children: [
                _buildModeCard(
                  title: "Mode Penyiraman Otomatis",
                  active: kontrol.modeOtomatis,
                  onPressed: () => toggleOtomatis(kontrol.modeOtomatis),
                ),

                const SizedBox(height: 20),
                _buildModeCard(
                  title: "Mode Penyiraman Manual",
                  active: kontrol.modeManual,
                  onPressed: () => toggleManual(kontrol.modeManual),
                ),

              ],
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
          selectedIndex: 1,
          onDestinationSelected: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
              return;
            }

            if (index == 1) {
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

  Widget _buildModeCard({
    required String title,
    required bool active,
    required VoidCallback onPressed,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: active
              ? AppColors.accentGreen.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: active
                ? [AppColors.lightGreen, Colors.white]
                : [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  active ? "● Aktif" : "● Nonaktif",
                  style: TextStyle(
                    color: active ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Icon(
                active ? Icons.power_settings_new : Icons.power_off,
                size: 70,
                color: active ? Colors.green : Colors.grey,
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        active ? AppColors.dangerRed : AppColors.accentGreen,

                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(vertical: 12),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  child: Text(
                    active ? "Matikan Mode" : "Nyalakan Mode",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
