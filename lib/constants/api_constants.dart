class ApiConstants {
  static const String baseUrl = 'https://jsonplaceholder.typicode.com';

  static const String todosUrl = '$baseUrl/todos';
  static const String usersUrl = '$baseUrl/users';

  static const Duration requestTimeout = Duration(seconds: 10);
}
