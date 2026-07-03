class LoginResponse {

  final bool success;
  final String message;
  final String? token;

  LoginResponse({
    required this.success,
    required this.message,
    this.token,
  });

  factory LoginResponse.fromJson(
    Map<String, dynamic> json,
  ) {

    return LoginResponse(
      success: json["success"] ?? false,
      message: json["message"] ?? "",
      token: json["token"],
    );
  }
}