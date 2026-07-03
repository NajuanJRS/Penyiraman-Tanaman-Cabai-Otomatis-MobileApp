import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:photo_view/photo_view.dart';
import 'package:excel/excel.dart' as excel;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/perkembangan.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import 'control_page.dart';
import 'dashboard_page.dart';

class HistoryItem {
  final Perkembangan perkembangan;
  final String decision;

  HistoryItem({required this.perkembangan, required this.decision});
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final ApiService api = ApiService();

  final ImagePicker picker = ImagePicker();

  final TextEditingController pageController = TextEditingController();

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  List<HistoryItem> allData = [];

  List<HistoryItem> filteredData = [];

  DateTime? selectedDateTime;

  final TextEditingController searchController = TextEditingController();

  int currentPage = 1;

  static const int itemsPerPage = 10;

  bool isLoading = true;
  String? errorMessage;

  void _showImagePreview(String imageUrl) {
    Navigator.push(
      context,

      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              backgroundColor: Colors.black,

              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
              ),

              body: PhotoView(
                imageProvider: NetworkImage(imageUrl),

                minScale: PhotoViewComputedScale.contained,

                maxScale: PhotoViewComputedScale.covered * 4,

                backgroundDecoration: const BoxDecoration(color: Colors.black),
              ),
            ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    initNotifications();

    loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    pageController.dispose();

    super.dispose();
  }

  Future<void> initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: android);

    await notifications.initialize(
      settings,

      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final path = response.payload;

        if (path != null) {
          await OpenFilex.open(path);
        }
      },
    );
  }

  Future<void> showDownloadNotification(
    String fileName,
    String filePath,
  ) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'download_channel',
          'Download',
          channelDescription: 'Notifikasi export file',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await notifications.show(
      1,
      'Download selesai',
      '$fileName berhasil disimpan',
      details,
      payload: filePath,
    );
  }

  Future<void> loadData() async {
    try {
      final perkembangan = await api.getPerkembangan();

      final prediksi = await api.getPrediksi();

      final List<HistoryItem> history = [];

      for (final item in perkembangan) {
        String decision = "-";

        try {
          final prediksiItem = prediksi.firstWhere(
            (p) => p.idPerkembangan == item.id,
          );

          decision = prediksiItem.decision;
        } catch (_) {}

        history.add(HistoryItem(perkembangan: item, decision: decision));
      }

      history.sort(
        (a, b) => DateTime.parse(
          b.perkembangan.waktu,
        ).compareTo(DateTime.parse(a.perkembangan.waktu)),
      );

      if (mounted) {
        setState(() {
          allData = history;

          applySearch(searchController.text);

          errorMessage = null;

          isLoading = false;
        });
      }
    } catch (e) {
      String msg = "Terjadi kesalahan";

      final text = e.toString().toLowerCase();

      if (text.contains("socketexception") ||
          text.contains("network is unreachable") ||
          text.contains("failed host lookup")) {
        msg = "Tidak ada koneksi internet";
      }

      if (mounted) {
        setState(() {
          isLoading = false;

          errorMessage = msg;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    try {
      final perkembangan = await api.getPerkembangan();
      final prediksi = await api.getPrediksi();

      final List<HistoryItem> history = [];

      for (final item in perkembangan) {
        String decision = "-";

        try {
          final prediksiItem = prediksi.firstWhere(
            (p) => p.idPerkembangan == item.id,
          );

          decision = prediksiItem.decision;
        } catch (_) {}

        history.add(HistoryItem(perkembangan: item, decision: decision));
      }

      history.sort(
        (a, b) => DateTime.parse(
          b.perkembangan.waktu,
        ).compareTo(DateTime.parse(a.perkembangan.waktu)),
      );

      if (mounted) {
        setState(() {
          allData = history;
          applySearch(searchController.text);
          errorMessage = null;
        });
      }
    } catch (_) {
      // Gagal refresh — data lama tetap ditampilkan
    }
  }

  void applySearch(String query) {
    query = query.toLowerCase();

    filteredData =
        allData.where((item) {
          final waktuApi = item.perkembangan.waktu.toLowerCase();

          final tanggalFormat =
              DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(DateTime.parse(item.perkembangan.waktu)).toLowerCase();

          final tanggalDetik =
              DateFormat(
                'dd/MM/yyyy HH:mm:ss',
              ).format(DateTime.parse(item.perkembangan.waktu)).toLowerCase();

          final tanggalSaja =
              DateFormat(
                'dd/MM/yyyy',
              ).format(DateTime.parse(item.perkembangan.waktu)).toLowerCase();

          final jamSaja =
              DateFormat(
                'HH:mm',
              ).format(DateTime.parse(item.perkembangan.waktu)).toLowerCase();

          return waktuApi.contains(query) ||
              tanggalFormat.contains(query) ||
              tanggalDetik.contains(query) ||
              tanggalSaja.contains(query) ||
              jamSaja.contains(query);
        }).toList();

    currentPage = 1;
  }

  Future<void> pickDateTime() async {
    final date = await showDatePicker(
      context: context,

      initialDate: selectedDateTime ?? DateTime.now(),

      firstDate: DateTime(2020),

      lastDate: DateTime(2100),
    );

    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDateTime ?? DateTime.now()),
    );

    if (time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      selectedDateTime = selected;

      searchController.text = DateFormat('dd/MM/yyyy HH:mm').format(selected);

      applySearch(searchController.text);
    });
  }

  int get totalPages {
    if (filteredData.isEmpty) {
      return 1;
    }

    return (filteredData.length / itemsPerPage).ceil();
  }

  List<HistoryItem> get currentItems {
    final start = (currentPage - 1) * itemsPerPage;

    int end = start + itemsPerPage;

    if (end > filteredData.length) {
      end = filteredData.length;
    }

    return filteredData.sublist(start, end);
  }

  Future<void> editImage(HistoryItem item) async {
    try {
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);

      if (file == null) return;

      await api.updateImage(item.perkembangan.id, File(file.path));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gambar berhasil diperbarui"),
            backgroundColor: Colors.green,
          ),
        );
      }

      await loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> deleteImage(HistoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: const Text("Konfirmasi"),

          content: const Text("Hapus gambar ini?"),

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
              child: const Text("Hapus"),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await api.deleteImage(item.perkembangan.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gambar berhasil dihapus")),
        );
      }

      await loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<File> getUniqueFile(String directoryPath) async {
    int counter = 0;

    String filePath = "$directoryPath/Data_Smart_Garden.xlsx";

    File file = File(filePath);

    while (await file.exists()) {
      counter++;

      filePath = "$directoryPath/Data_Smart_Garden($counter).xlsx";

      file = File(filePath);
    }

    return file;
  }

  Future<void> confirmExportExcel() async {
    final confirm = await showDialog<bool>(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: const Text("Konfirmasi Export"),

          content: Text(
            "Data yang akan diexport:\n\n"
            "• Total data: ${allData.length}\n"
            "• Format: Excel (.xlsx)\n"
            "• Lokasi: Folder Download\n\n"
            "Lanjutkan export?",
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },

              child: const Text("Batal"),
            ),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, true);
              },

              icon: const Icon(Icons.download),

              label: const Text("Export"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await exportExcel();
    }
  }

  Future<void> exportExcel() async {
    try {
      final status = await Permission.manageExternalStorage.request();

      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Izin penyimpanan ditolak")),
        );

        return;
      }

      final excelFile = excel.Excel.createExcel();

      final sheet = excelFile['Data Sensor'];

      sheet.appendRow([
        excel.TextCellValue("No"),
        excel.TextCellValue("Tanggal"),
        excel.TextCellValue("Kelembapan Tanah"),
        excel.TextCellValue("Kelembapan Udara"),
        excel.TextCellValue("Suhu"),
        excel.TextCellValue("Keputusan"),
      ]);

      final exportData = List<HistoryItem>.from(allData);

      exportData.sort(
        (a, b) => DateTime.parse(
          a.perkembangan.waktu,
        ).compareTo(DateTime.parse(b.perkembangan.waktu)),
      );

      for (int i = 0; i < exportData.length; i++) {
        final item = exportData[i];

        final waktu = DateFormat(
          'dd/MM/yyyy HH:mm:ss',
        ).format(DateTime.parse(item.perkembangan.waktu));

        sheet.appendRow([
          excel.IntCellValue(i + 1),
          excel.TextCellValue(waktu),
          excel.DoubleCellValue(item.perkembangan.kelembapanTanah),
          excel.DoubleCellValue(item.perkembangan.kelembapanUdara),
          excel.DoubleCellValue(item.perkembangan.suhu),
          excel.TextCellValue(item.decision),
        ]);
      }

      final downloadDir = Directory('/storage/emulated/0/Download');

      final file = await getUniqueFile(downloadDir.path);

      // SIMPAN FILE EXCEL
      await file.writeAsBytes(excelFile.encode()!);

      await showDownloadNotification(file.path.split('/').last, file.path);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            "File berhasil disimpan:\n${file.path.split('/').last}",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Export gagal: $e")));
    }
  }

  Widget _buildMiniSensor(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Histori Perkembangan"),
        centerTitle: false,
      ),

      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 90, color: Colors.red),

                    const SizedBox(height: 20),

                    const Text(
                      "Gagal memuat data riwayat",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(errorMessage!),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          isLoading = true;

                          errorMessage = null;
                        });

                        loadData();
                      },

                      icon: const Icon(Icons.refresh),

                      label: const Text("Coba Lagi"),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: "Cari tanggal atau jam",
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (selectedDateTime != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        selectedDateTime = null;
                                        searchController.clear();
                                        applySearch("");
                                      });
                                    },
                                  ),

                                IconButton(
                                  icon: const Icon(Icons.calendar_month),
                                  onPressed: pickDateTime,
                                ),
                              ],
                            ),

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ),

                          onChanged: (value) {
                            setState(() {
                              applySearch(value);
                            });
                          },
                        ),

                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),

                            onPressed: confirmExportExcel,
                            icon: const Icon(Icons.download),
                            label: const Text("Export Excel"),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: AppColors.primaryGreen,
                      child:
                        filteredData.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.4,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.shade300),
                                          const SizedBox(height: 12),
                                          Text(
                                            "Tidak ada data",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                              itemCount: currentItems.length,

                              itemBuilder: (context, index) {
                                final item = currentItems[index];

                                final nomorData =
                                    ((currentPage - 1) * itemsPerPage) +
                                    index +
                                    1;

                                final waktu = DateTime.parse(
                                  item.perkembangan.waktu,
                                );

                                final gambar = item.perkembangan.gambar;

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),

                                  child: Padding(
                                    padding: const EdgeInsets.all(16),

                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,

                                          children: [
                                            Text(
                                              "Data ke-$nomorData dari ${filteredData.length}",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryGreen,
                                              ),
                                            ),

                                            Text(
                                              DateFormat(
                                                'dd/MM/yyyy HH:mm',
                                              ).format(waktu),

                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        Row(
                                          children: [
                                            _buildMiniSensor(
                                              Icons.water_drop,
                                              "Tanah",
                                              "${item.perkembangan.kelembapanTanah.toStringAsFixed(1)}%",
                                              AppColors.soilBrown,
                                            ),
                                            const SizedBox(width: 6),
                                            _buildMiniSensor(
                                              Icons.air,
                                              "Udara",
                                              "${item.perkembangan.kelembapanUdara.toStringAsFixed(1)}%",
                                              AppColors.waterBlue,
                                            ),
                                            const SizedBox(width: 6),
                                            _buildMiniSensor(
                                              Icons.thermostat,
                                              "Suhu",
                                              "${item.perkembangan.suhu.toStringAsFixed(1)}°C",
                                              AppColors.temperatureOrange,
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 8),

                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),

                                          decoration: BoxDecoration(
                                            color:
                                                item.decision == "Siram"
                                                    ? Colors.green.shade100
                                                    : Colors.red.shade100,

                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),

                                            border: Border.all(
                                              color:
                                                  item.decision == "Siram"
                                                      ? Colors.green.shade300
                                                      : Colors.red.shade300,
                                            ),
                                          ),

                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,

                                            children: [
                                              Icon(
                                                item.decision == "Siram"
                                                    ? Icons.water_drop
                                                    : Icons.block,

                                                size: 18,

                                                color:
                                                    item.decision == "Siram"
                                                        ? Colors.green.shade800
                                                        : Colors.red.shade800,
                                              ),

                                              const SizedBox(width: 6),

                                              Text(
                                                "Keputusan : ${item.decision}",

                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,

                                                  color:
                                                      item.decision == "Siram"
                                                          ? Colors
                                                              .green
                                                              .shade800
                                                          : Colors.red.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 12),

                                        if (gambar != null)
                                          GestureDetector(
                                            onTap: () {
                                              _showImagePreview(
                                                "https://cabaiot.tech/storage/$gambar",
                                              );
                                            },

                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),

                                              child: Image.network(
                                                "https://cabaiot.tech/storage/$gambar",

                                                height: 270,

                                                width: double.infinity,

                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            height: 170,

                                            width: double.infinity,

                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.grey,
                                              ),

                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),

                                            child: const Center(
                                              child: Text("Belum ada gambar"),
                                            ),
                                          ),

                                        const SizedBox(height: 12),

                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  editImage(item);
                                                },

                                                icon: const Icon(Icons.edit),

                                                label: Text(
                                                  gambar == null
                                                      ? "Tambah Gambar"
                                                      : "Edit Gambar",
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 10),

                                            if (gambar != null)
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    deleteImage(item);
                                                  },

                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,

                                                        foregroundColor:
                                                            Colors.white,
                                                      ),

                                                  icon: const Icon(
                                                    Icons.delete,
                                                  ),

                                                  label: const Text(
                                                    "Hapus Gambar",
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        TextButton(
                          onPressed:
                              currentPage > 1
                                  ? () {
                                    setState(() {
                                      currentPage--;
                                    });
                                  }
                                  : null,
                          child: const Text(
                            "Prev",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),

                        SizedBox(
                          width: 55,
                          height: 40,
                          child: TextField(
                            controller: pageController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: "$currentPage",
                              filled: true,
                              fillColor: AppColors.lightGreen,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),

                            onSubmitted: (value) {
                              final page = int.tryParse(value);
                              if (page != null &&
                                  page >= 1 &&
                                  page <= totalPages) {
                                setState(() {
                                  currentPage = page;
                                });
                              }
                              pageController.clear();
                            },
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "/ $totalPages",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),

                        TextButton(
                          onPressed:
                              currentPage < totalPages
                                  ? () {
                                    setState(() {
                                      currentPage++;
                                    });
                                  }
                                  : null,
                          child: const Text(
                            "Next",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
          selectedIndex: 2,
          onDestinationSelected: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
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
