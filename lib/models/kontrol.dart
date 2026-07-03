class Kontrol {
  final bool modeManual;
  final bool modeOtomatis;
  final double batasKelembapan;

  Kontrol({
    required this.modeManual,
    required this.modeOtomatis,
    required this.batasKelembapan,
  });

  factory Kontrol.fromJson(Map<String, dynamic> json) {
    return Kontrol(
      modeManual: json["mode_manual"] == 1 || json["mode_manual"] == true,

      modeOtomatis: json["mode_otomatis"] == 1 || json["mode_otomatis"] == true,

      batasKelembapan:
          double.tryParse(json["batas_kelembapan"].toString()) ?? 0,
    );
  }
}
