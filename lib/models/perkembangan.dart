class Perkembangan {

  final int id;
  final double kelembapanTanah;
  final double kelembapanUdara;
  final double suhu;
  final String waktu;
  final String? gambar;

  Perkembangan({
    required this.id,
    required this.kelembapanTanah,
    required this.kelembapanUdara,
    required this.suhu,
    required this.waktu,
    this.gambar,
  });

  factory Perkembangan.fromJson(Map<String,dynamic> json){

    return Perkembangan(
      id: json["id_perkembangan"],
      kelembapanTanah:
          double.parse(json["kelembapan_tanah"].toString()),
      kelembapanUdara:
          double.parse(json["kelembapan_udara"].toString()),
      suhu:
          double.parse(json["suhu"].toString()),
      waktu: json["waktu"],
      gambar: json["gambar"],
    );
  }
}