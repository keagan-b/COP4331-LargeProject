import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const baseUrl = "http://group7.sedsucf.org";
  static const _timeout = Duration(seconds: 10);

  // Stores the session token after a successful login
  static String? sessionToken;

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/api/user/login"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": email,
            "password": password,
          }),
        )
        .timeout(_timeout);

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 &&
        data["sessionToken"] != null &&
        data["sessionToken"] != '') {
      sessionToken = data["sessionToken"];
      return {"success": true, ...data};
    }

    return {"success": false, ...data};
  }

  static Future<Map<String, dynamic>> signup(
      String email, String password) async {
    final response = await http
        .post(
          Uri.parse("$baseUrl/api/user/register"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "email": email,
            "password": password,
          }),
        )
        .timeout(_timeout);

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {"success": true, ...data};
    }

    return {"success": false, ...data};
  }

  static Future<Map<String, dynamic>> resetPassword(String email) async {
    final uri = Uri.parse("$baseUrl/api/user/request-password-reset")
        .replace(queryParameters: {"email": email});

    final response = await http.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      return {"success": true};
    }

    return {"success": false, "error": response.body};
  }
}