import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../models/todo.dart';
import '../models/app_user.dart';

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  final http.Client _client = http.Client();

  Future<http.Response> _get(Uri uri) async {
    try {
      final response = await _client
          .get(uri)
          .timeout(ApiConstants.requestTimeout);

      _checkStatus(response);
      return response;
    } on TimeoutException {
      throw const ApiException('Час очікування вичерпано.');
    } on http.ClientException {
      throw const ApiException('Немає підключення до інтернету.');
    }
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final request = http.Request(method, uri);

      request.headers['Content-Type'] = 'application/json; charset=UTF-8';

      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamed = await _client
          .send(request)
          .timeout(ApiConstants.requestTimeout);

      final response = await http.Response.fromStream(streamed);

      _checkStatus(response);
      return response;
    } on TimeoutException {
      throw const ApiException('Час очікування вичерпано.');
    } on http.ClientException {
      throw const ApiException('Помилка підключення до сервера.');
    }
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode == 404) {
      throw const ApiException('404: Ресурс не знайдено.');
    }

    if (response.statusCode >= 500) {
      throw const ApiException('Помилка сервера.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('HTTP помилка: ${response.statusCode}');
    }
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const ApiException('Некоректний JSON.');
    }
  }

  // GET /todos або GET /todos?userId=id
  Future<List<Todo>> getTodos({int? userId}) async {
    final uri = Uri.parse(
      ApiConstants.todosUrl,
    ).replace(queryParameters: userId == null ? null : {'userId': '$userId'});

    final response = await _get(uri);
    final data = _decode(response);

    if (data is! List) {
      throw const ApiException('Некоректний список задач.');
    }

    try {
      return data.map((item) => Todo.fromJson(item)).toList();
    } catch (_) {
      throw const ApiException('Помилка читання задач.');
    }
  }

  // GET /users
  Future<List<AppUser>> getUsers() async {
    final response = await _get(Uri.parse(ApiConstants.usersUrl));

    final data = _decode(response);

    if (data is! List) {
      throw const ApiException('Некоректний список користувачів.');
    }

    try {
      return data.map((item) => AppUser.fromJson(item)).toList();
    } catch (_) {
      throw const ApiException('Помилка читання користувачів.');
    }
  }

  // POST /todos
  Future<Todo> createTodo(Todo todo) async {
    final response = await _send(
      'POST',
      Uri.parse(ApiConstants.todosUrl),
      body: {
        'userId': todo.userId,
        'title': todo.title,
        'completed': todo.completed,
      },
    );

    final data = _decode(response);

    if (data is! Map<String, dynamic>) {
      throw const ApiException('Некоректна відповідь сервера.');
    }

    return todo.copyWith(id: (data['id'] as num?)?.toInt() ?? todo.id);
  }

  // PUT /todos/{id}
  Future<void> updateTodo(Todo todo) async {
    final response = await _send(
      'PUT',
      Uri.parse('${ApiConstants.todosUrl}/${todo.id}'),
      body: todo.toJson(),
    );

    _decode(response);
  }

  // PATCH /todos/{id}
  Future<void> updateCompleted(int id, bool completed) async {
    final response = await _send(
      'PATCH',
      Uri.parse('${ApiConstants.todosUrl}/$id'),
      body: {'completed': completed},
    );

    _decode(response);
  }

  // DELETE /todos/{id}
  Future<void> deleteTodo(int id) async {
    final response = await _send(
      'DELETE',
      Uri.parse('${ApiConstants.todosUrl}/$id'),
    );

    _decode(response);
  }

  void dispose() {
    _client.close();
  }
}
