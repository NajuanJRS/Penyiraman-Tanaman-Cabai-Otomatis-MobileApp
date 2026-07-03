import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final bool siram = widget.decision.toLowerCase().trim() == "siram";

    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Text(
                "Apakah tanaman perlu disiram?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),

              const SizedBox(height: 15),

              Text(
                "Input : Tanah ${widget.tanah.toStringAsFixed(1)}% | "
                "Suhu ${widget.suhu.toStringAsFixed(1)}°C | "
                "Udara ${widget.udara.toStringAsFixed(1)}%",
              ),

              const SizedBox(height: 15),

              if (!siram)
                const Text(
                  "Tidak, tanaman tidak perlu disiram",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

              if (siram) ...[
                const Text(
                  "Ya, tanaman perlu disiram",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 15),

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

                                        child: const Text("Ya"),
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

                    icon: const Icon(Icons.water_drop),

                    label: Text(isWatering ? "Menyiram..." : "Siram Sekarang"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
