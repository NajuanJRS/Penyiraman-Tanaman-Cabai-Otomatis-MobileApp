import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class DecisionTreeCard extends StatefulWidget {
  final double tanah;
  final double udara;
  final double suhu;
  final String decision;

  const DecisionTreeCard({
    super.key,
    required this.tanah,
    required this.udara,
    required this.suhu,
    required this.decision,
  });

  @override
  State<DecisionTreeCard> createState() => _DecisionTreeCardState();
}

class _DecisionTreeCardState extends State<DecisionTreeCard> {
  final ApiService api = ApiService();

  bool isWatering = false;

  Future<void> startWatering() async {
    try {
      setState(() {
        isWatering = true;
      });

      await api.updateKontrol(id: 1, modeManual: true, modeOtomatis: false);

      await Future.delayed(const Duration(seconds: 8));

      await api.updateKontrol(id: 1, modeManual: false, modeOtomatis: false);
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          isWatering = false;
        });
      }
    }
  }

  Widget _buildSensorBadge(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color.withValues(alpha: 0.7)),
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
                fontSize: 14,
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
    final bool siram = widget.decision.toLowerCase().trim() == "siram";

    return SizedBox(
      width: double.infinity,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: siram
                ? AppColors.accentGreen.withValues(alpha: 0.3)
                : Colors.grey.shade200,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: siram
                  ? [Colors.white, AppColors.lightGreen.withValues(alpha: 0.3)]
                  : [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.eco,
                        size: 20,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Prediksi Penyiraman",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Sensor input badges
                Row(
                  children: [
                    _buildSensorBadge(
                      Icons.water_drop,
                      "Tanah",
                      "${widget.tanah.toStringAsFixed(1)}%",
                      AppColors.soilBrown,
                    ),
                    const SizedBox(width: 8),
                    _buildSensorBadge(
                      Icons.thermostat,
                      "Suhu",
                      "${widget.suhu.toStringAsFixed(1)}°C",
                      AppColors.temperatureOrange,
                    ),
                    const SizedBox(width: 8),
                    _buildSensorBadge(
                      Icons.air,
                      "Udara",
                      "${widget.udara.toStringAsFixed(1)}%",
                      AppColors.waterBlue,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Decision result
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: siram
                        ? AppColors.accentGreen.withValues(alpha: 0.1)
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: siram
                          ? AppColors.accentGreen.withValues(alpha: 0.3)
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        siram ? Icons.check_circle : Icons.info_outline,
                        size: 22,
                        color: siram ? AppColors.primaryGreen : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          siram
                              ? "Tanaman perlu disiram"
                              : "Tanaman tidak perlu disiram",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: siram ? AppColors.primaryGreen : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Water button (only shown when siram)
                if (siram) ...[
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,

                    child: ElevatedButton.icon(
                      onPressed:
                          isWatering
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,

                                    builder: (context) {
                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        title: const Text("Konfirmasi Penyiraman"),

                                        content: const Text(
                                          "Apakah Anda yakin ingin menyalakan pompa air selama 8 detik?",
                                        ),

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
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primaryGreen,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: const Text("Ya, Siram"),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirm == true) {
                                    await startWatering();

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Pompa berhasil dinyalakan",
                                          ),

                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  }
                                },

                      icon: Icon(isWatering ? Icons.hourglass_top : Icons.water_drop),

                      label: Text(isWatering ? "Menyiram..." : "Siram Sekarang"),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primaryGreen.withValues(alpha: 0.5),
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
