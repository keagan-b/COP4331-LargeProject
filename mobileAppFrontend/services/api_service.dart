import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const baseUrl = "http://group7.sedsucf.org";

  // Stores the session token after a successful login
  static String? sessionToken;

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/api/user/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    final data = jsonDecode(response.body);

    // Store the session token if login succeeded
    if (response.statusCode == 200 && data["sessionToken"] != null && data["sessionToken"] != '') {
      sessionToken = data["sessionToken"];
      return {"success": true, ...data};
    }

    return {"success": false, ...data};
  }

  // Server only expects email + password (no name field)
  static Future<Map<String, dynamic>> signup(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/api/user/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {"success": true, ...data};
    }

    return {"success": false, ...data};
  }

  // Server uses a GET request with email as a query parameter
  static Future<Map<String, dynamic>> resetPassword(String email) async {
    final uri = Uri.parse("$baseUrl/api/user/request-password-reset")
        .replace(queryParameters: {"email": email});

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return {"success": true};
    }

    return {"success": false, "error": response.body};
  }
}