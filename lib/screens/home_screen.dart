import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/todo.dart';
import '../services/api_service.dart';
import '../widgets/todo_tile.dart';

enum TodoFilter { all, completed, pending }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();

  List<Todo> _todos = [];
  List<AppUser> _users = [];

  bool _loading = true;
  String? _error;

  TodoFilter _filter = TodoFilter.all;

  int? _selectedUserId;

  String _search = '';

  int _nextLocalId = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  // Завантаження задач та користувачів
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getTodos(userId: _selectedUserId),
        _api.getUsers(),
      ]);

      if (!mounted) return;

      setState(() {
        _todos = results[0] as List<Todo>;
        _users = results[1] as List<AppUser>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Фільтрація та пошук задач
  List<Todo> get _visibleTodos {
    return _todos.where((todo) {
      final matchesFilter = switch (_filter) {
        TodoFilter.all => true,
        TodoFilter.completed => todo.completed,
        TodoFilter.pending => !todo.completed,
      };

      final matchesSearch = todo.title.toLowerCase().contains(
        _search.toLowerCase(),
      );

      return matchesFilter && matchesSearch;
    }).toList();
  }

  // Статистика
  int get _completed {
    return _todos.where((todo) => todo.completed).length;
  }

  int get _pending {
    return _todos.length - _completed;
  }

  // Отримання імені користувача
  String _userName(int id) {
    for (final user in _users) {
      if (user.id == id) {
        return user.name;
      }
    }

    return 'Користувач $id';
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Зміна статусу задачі через PATCH
  Future<void> _toggleTodo(Todo todo, bool value) async {
    final index = _todos.indexWhere((item) => item.id == todo.id);

    if (index == -1) return;

    final oldTodo = _todos[index];

    setState(() {
      _todos[index] = oldTodo.copyWith(completed: value);
    });

    try {
      await _api.updateCompleted(todo.id, value);

      if (mounted) {
        _message('Статус задачі оновлено');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _todos[index] = oldTodo;
      });

      _message(e.toString());
    }
  }

  // Редагування назви задачі через PUT
  Future<void> _editTodo(Todo todo) async {
    final controller = TextEditingController(text: todo.title);

    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Редагувати задачу'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Назва задачі'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              Navigator.pop(context, controller.text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Скасувати'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Зберегти'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (title == null || title.isEmpty) return;

    final index = _todos.indexWhere((item) => item.id == todo.id);

    if (index == -1) return;

    final updatedTodo = todo.copyWith(title: title);

    setState(() {
      _todos[index] = updatedTodo;
    });

    try {
      await _api.updateTodo(updatedTodo);

      if (mounted) {
        _message('Задачу змінено');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _todos[index] = todo;
      });

      _message(e.toString());
    }
  }

  // Створення нової задачі через POST
  Future<void> _addTodo() async {
    final controller = TextEditingController();

    int userId = _selectedUserId ?? (_users.isNotEmpty ? _users.first.id : 1);

    final result = await showDialog<_NewTodo>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Нова задача'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Назва задачі',
                    ),
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    initialValue: userId,
                    decoration: const InputDecoration(labelText: 'Користувач'),
                    items: _users.map((user) {
                      return DropdownMenuItem<int>(
                        value: user.id,
                        child: Text(user.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          userId = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 8),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Статус: не виконано'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Скасувати'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = controller.text.trim();

                    if (title.isNotEmpty) {
                      Navigator.pop(context, _NewTodo(title, userId));
                    }
                  },
                  child: const Text('Створити'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (result == null) return;

    final draft = Todo(
      userId: result.userId,
      id: _nextLocalId--,
      title: result.title,
      completed: false,
    );

    try {
      final createdTodo = await _api.createTodo(draft);

      if (!mounted) return;

      setState(() {
        _todos.insert(0, createdTodo);
      });

      _message('Задачу створено');
    } catch (e) {
      if (mounted) {
        _message(e.toString());
      }
    }
  }

  // Видалення задачі
  Future<void> _deleteTodo(Todo todo, {bool confirm = true}) async {
    if (confirm) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Видалити задачу?'),
            content: Text('«${todo.title}» буде видалено зі списку.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text('Скасувати'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text('Видалити'),
              ),
            ],
          );
        },
      );

      if (accepted != true) return;
    }

    final index = _todos.indexWhere((item) => item.id == todo.id);

    if (index == -1) return;

    if (!mounted) return;

    setState(() {
      _todos.removeAt(index);
    });

    final messenger = ScaffoldMessenger.of(context);

    messenger.clearSnackBars();

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: const Text('Завдання видалено')));

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Задачу видалено'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            if (!mounted) return;

            setState(() {
              _todos.insert(index.clamp(0, _todos.length), todo);
            });
          },
        ),
      ),
    );

    try {
      await _api.deleteTodo(todo.id);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (!_todos.any((item) => item.id == todo.id)) {
          _todos.insert(index.clamp(0, _todos.length), todo);
        }
      });

      _message(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _todos.isEmpty ? 0.0 : _completed / _todos.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Мої задачі',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Оновити',
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _users.isEmpty ? null : _addTodo,
        icon: const Icon(Icons.add),
        label: const Text('Додати'),
      ),

      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _loadData)
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 90),
                  children: [
                    // Статистика
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: _StatisticsCard(
                        total: _todos.length,
                        completed: _completed,
                        pending: _pending,
                        progress: progress,
                      ),
                    ),

                    // Вибір користувача
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<int?>(
                        initialValue: _selectedUserId,
                        decoration: const InputDecoration(
                          labelText: 'Задачі користувача',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Усі користувачі'),
                          ),
                          ..._users.map((user) {
                            return DropdownMenuItem<int?>(
                              value: user.id,
                              child: Text(user.name),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedUserId = value;
                          });

                          _loadData();
                        },
                      ),
                    ),

                    // Пошук
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _search = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Пошук за назвою...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    // Фільтри
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: SegmentedButton<TodoFilter>(
                        segments: const [
                          ButtonSegment(
                            value: TodoFilter.all,
                            label: Text('Усі'),
                          ),
                          ButtonSegment(
                            value: TodoFilter.completed,
                            label: Text('Виконані'),
                          ),
                          ButtonSegment(
                            value: TodoFilter.pending,
                            label: Text('Очікують'),
                          ),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (value) {
                          setState(() {
                            _filter = value.first;
                          });
                        },
                      ),
                    ),

                    // Список задач або порожній екран
                    if (_visibleTodos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(36),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 52,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Задач не знайдено',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._visibleTodos.map((todo) {
                        return Dismissible(
                          key: ValueKey(todo.id),
                          direction: DismissDirection.endToStart,

                          // Фон при свайпі
                          background: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 5,
                            ),
                            padding: const EdgeInsets.only(right: 20),
                            alignment: Alignment.centerRight,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),

                          // Підтвердження видалення
                          confirmDismiss: (_) async {
                            final accepted = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Видалити задачу?'),
                                  content: Text(
                                    '«${todo.title}» буде видалено.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context, false);
                                      },
                                      child: const Text('Скасувати'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        Navigator.pop(context, true);
                                      },
                                      child: const Text('Видалити'),
                                    ),
                                  ],
                                );
                              },
                            );

                            return accepted == true;
                          },

                          onDismissed: (_) {
                            _deleteTodo(todo, confirm: false);
                          },

                          child: TodoTile(
                            todo: todo,
                            userName: _userName(todo.userId),
                            onChanged: (value) {
                              if (value != null) {
                                _toggleTodo(todo, value);
                              }
                            },
                            onEdit: () {
                              _editTodo(todo);
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}

// Дані нової задачі
class _NewTodo {
  final String title;
  final int userId;

  const _NewTodo(this.title, this.userId);
}

// Картка статистики
class _StatisticsCard extends StatelessWidget {
  final int total;
  final int completed;
  final int pending;
  final double progress;

  const _StatisticsCard({
    required this.total,
    required this.completed,
    required this.pending,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Прогрес виконання',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: progress, minHeight: 9),
            ),

            const SizedBox(height: 8),

            Text('${(progress * 100).round()}% виконано'),

            const Divider(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatValue(label: 'Усього', value: total),
                _StatValue(label: 'Виконано', value: completed),
                _StatValue(label: 'Очікують', value: pending),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Окремий показник статистики
class _StatValue extends StatelessWidget {
  final String label;
  final int value;

  const _StatValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

// Екран помилки завантаження
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 54, color: Colors.grey),

            const SizedBox(height: 12),

            const Text(
              'Не вдалося завантажити дані',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(message, textAlign: TextAlign.center),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторити'),
            ),
          ],
        ),
      ),
    );
  }
}
