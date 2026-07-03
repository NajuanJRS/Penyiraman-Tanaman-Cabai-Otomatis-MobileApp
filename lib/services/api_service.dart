import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/perkembangan.dart';
import '../models/prediksi.dart';
import '../models/kontrol.dart';
import '../models/login_response.dart';

class ApiService {
  static const String baseUrl = "http://127.0.0.1:8000/api";

  static const String apiKey = "kelompoksmartgarden1";

  Future<LoginResponse> login(String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),

      headers: {"Accept": "application/json", "X-API-KEY": apiKey},

      body: {"password": password},
    ).timeout(const Duration(seconds: 15));

    final jsonData = jsonDecode(response.body);

    return LoginResponse.fromJson(jsonData);
  }

  Future<void> saveFcmToken(String token) async {
    await http.post(
      Uri.parse("$baseUrl/fcm-token"),

      headers: {"Accept": "application/json", "X-API-KEY": apiKey},

      body: {"token": token},
    ).timeout(const Duration(seconds: 15));
  }

  // =========================
  // PERKEMBANGAN
  // =========================

  Future<List<Perkembangan>> getPerkembangan() async {
    final response = await http.get(
      Uri.parse("$baseUrl/perkembangan"),

      headers: {"X-API-KEY": apiKey, "Accept": "application/json"},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);

      List data = jsonData["data"];

      return data.map((e) => Perkembangan.fromJson(e)).toList();
    }

    throw Exception("Gagal mengambil data");
  }

  // =========================
  // PREDIKSI
  // =========================

  Future<List<Prediksi>> getPrediksi() async {
    final response = await http.get(
      Uri.parse("$baseUrl/prediksi"),

      headers: {"X-API-KEY": apiKey, "Accept": "application/json"},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);

      List data = jsonData["data"];

      return data.map((e) => Prediksi.fromJson(e)).toList();
    }

    throw Exception("Gagal mengambil data");
  }

  // =========================
  // UPDATE GAMBAR
  // =========================

  Future<void> updateImage(int id, File imageFile) async {
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/perkembangan/$id/gambar"),
    );

    request.headers["X-API-KEY"] = apiKey;

    request.files.add(
      await http.MultipartFile.fromPath("gambar", imageFile.path),
    );

    final response = await request.send().timeout(const Duration(seconds: 30));

    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(responseBody);
    }
  }

  // =========================
  // HAPUS GAMBAR
  // =========================

  Future<void> deleteImage(int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/perkembangan/$id/gambar"),

      headers: {"X-API-KEY": apiKey, "Accept": "application/json"},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception("Gagal hapus gambar");
    }
  }

  // =========================
  // KONTROL
  // =========================

  Future<Kontrol> getKontrol() async {
    final response = await http.get(
      Uri.parse("$baseUrl/kontrol"),
      headers: {"X-API-KEY": apiKey, "Accept": "application/json"},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);

      return Kontrol.fromJson(jsonData);
    }

    throw Exception("Gagal mengambil data");
  }

  Future<void> updateKontrol({
    required int id,
    required bool modeManual,
    required bool modeOtomatis,
    double? batasKelembapan,
  }) async {
    final response = await http.put(
      Uri.parse("$baseUrl/kontrol/$id"),

      headers: {"X-API-KEY": apiKey, "Accept": "application/json"},

      body: {
        "mode_manual": modeManual ? "1" : "0",
        "mode_otomatis": modeOtomatis ? "1" : "0",
        if (batasKelembapan != null)
          "batas_kelembapan": batasKelembapan.toString(),
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      var message = "Gagal memperbarui kontrol";

      try {
        final jsonData = jsonDecode(response.body);
        final errors = jsonData["errors"];

        if (errors is Map && errors.isNotEmpty) {
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            message = firstError.first.toString();
          }
        } else if (jsonData["message"] != null) {
          message = jsonData["message"].toString();
        }
      } catch (_) {
        // Gunakan pesan umum jika respons server bukan JSON.
      }

      throw Exception(message);
    }
  }
}
