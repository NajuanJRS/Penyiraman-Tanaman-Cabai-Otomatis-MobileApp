class Prediksi {

  final int idPerkembangan;
  final String decision;

  Prediksi({
    required this.idPerkembangan,
    required this.decision,
  });

  factory Prediksi.fromJson(Map<String,dynamic> json){

    return Prediksi(
      idPerkembangan: json["id_perkembangan"],
      decision: json["decision"],
    );
  }
}