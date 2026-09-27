import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'api.dart';

void main() => runApp(const CollegeApp());

class CollegeApp extends StatefulWidget {
  const CollegeApp({super.key});

  @override
  State<CollegeApp> createState() => _CollegeAppState();
}

class _CollegeAppState extends State<CollegeApp> {
  Map<String, dynamic>? user;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'College Management System',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF284B63)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: user == null
          ? LoginPage(
              onLogin: (value) => setState(() => user = value),
            )
          : CollegeShell(
              user: user!,
              onLogout: () {
                Api.instance.clearToken();
                setState(() => user = null);
              },
            ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onLogin;

  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final tokenController = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    usernameController.dispose();
    tokenController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final username = usernameController.text.trim();
    final token = tokenController.text.trim();

    if (username.isEmpty) {
      setState(() {
        error = 'Enter your college username.';
      });
      return;
    }

    if (token.isEmpty) {
      setState(() {
        error = 'Enter your college API token.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      // The API token is shared by role. The username selects the
      // individual college account within that role.
      Api.instance.setIdentity(username, token);

      final response = await Api.instance.get('/me');

      dynamic raw = response.data;

      if (raw is String) {
        raw = jsonDecode(raw);
      }

      if (raw is! Map) {
        throw Exception(
          'Unexpected /me response type: ${raw.runtimeType}',
        );
      }

      final body = Map<String, dynamic>.from(raw);
      final userValue = body['user'];

      if (userValue is Map) {
        final backendUser = Map<String, dynamic>.from(userValue);
        backendUser['role'] = (body['role'] ?? backendUser['role'] ?? 'STUDENT')
            .toString()
            .toUpperCase();

        // Keep the exact account username used for this session.
        backendUser['username'] = backendUser['username'] ?? username;

        widget.onLogin(backendUser);
        return;
      }

      throw Exception('Authenticated, but /me returned no user data.');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;

      String serverMessage = '';

      if (data is Map && data['message'] != null) {
        serverMessage = data['message'].toString();
      } else if (data is String && data.trim().isNotEmpty) {
        serverMessage = data.trim();
      }

      if (status != null) {
        throw Exception(
          'HTTP $status${serverMessage.isEmpty ? '' : ': $serverMessage'}',
        );
      }

      throw Exception(
        'Network error: ${e.message ?? 'Could not reach the college API.'}',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error =
              'Login failed: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.school_rounded, size: 48),
                    const SizedBox(height: 20),
                    Text(
                      'College Management',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in with your individual college account.',
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: usernameController,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'rahul',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: tokenController,
                      obscureText: true,
                      onSubmitted: (_) => login(),
                      decoration: const InputDecoration(
                        labelText: 'College API token',
                        hintText: 'student_2026',
                        prefixIcon: Icon(Icons.key_rounded),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Students: student_2026  •  Faculty: faculty_2026',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: loading ? null : login,
                        child: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Sign in'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CollegeShell extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  const CollegeShell({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<CollegeShell> createState() => _CollegeShellState();
}

class _CollegeShellState extends State<CollegeShell> {
  int index = 0;

  List<_Nav> get nav {
    final role = (widget.user['role'] ?? '').toString().toUpperCase();

    final common = <_Nav>[
      _Nav('Dashboard', Icons.dashboard_outlined, const DashboardPage()),
    ];

    if (role == 'STUDENT') {
      return [
        ...common,
        _Nav('My Profile', Icons.person_outline, const StudentsPage()),
        _Nav('My Attendance', Icons.fact_check_outlined,
            const AttendancePage(role: 'STUDENT')),
        _Nav('My Reports', Icons.bar_chart_outlined, const ReportsPage()),
      ];
    }

    if (role == 'FACULTY') {
      return [
        ...common,
        _Nav('Students', Icons.people_outline, const StudentsPage()),
        _Nav('Subjects', Icons.menu_book_outlined, const AcademicsPage()),
        _Nav('Attendance', Icons.fact_check_outlined,
            AttendancePage(role: role)),
        _Nav('Reports', Icons.bar_chart_outlined, const ReportsPage()),
      ];
    }

    if (role == 'HOD') {
      return [
        ...common,
        _Nav('Department', Icons.account_tree_outlined, const AcademicsPage()),
        _Nav('Students', Icons.people_outline, const StudentsPage()),
        _Nav('Faculty', Icons.badge_outlined, const FacultyPage()),
        _Nav('Attendance', Icons.fact_check_outlined,
            AttendancePage(role: role)),
        _Nav('Approvals', Icons.approval_outlined,
            const AttendancePage(role: 'HOD')),
        _Nav('Reports', Icons.bar_chart_outlined, const ReportsPage()),
      ];
    }

    final adminNav = [
      ...common,
      _Nav('Students', Icons.people_outline, const StudentsPage()),
      _Nav('Academics', Icons.account_tree_outlined, const AcademicsPage()),
      _Nav('Attendance', Icons.fact_check_outlined, AttendancePage(role: role)),
      _Nav('Faculty', Icons.badge_outlined, const FacultyPage()),
      _Nav('Reports', Icons.bar_chart_outlined, const ReportsPage()),
    ];

    if (role == 'SUPER_ADMIN') {
      return [
        ...adminNav,
        _Nav('Administration', Icons.admin_panel_settings_outlined,
            AdminPage(role: role)),
        _Nav('Security', Icons.shield_outlined, const SecurityPage()),
      ];
    }

    return [
      ...adminNav,
      if (role == 'ADMIN')
        _Nav('Administration', Icons.admin_panel_settings_outlined,
            AdminPage(role: role)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = nav;
    if (index >= items.length) index = 0;

    final role = (widget.user['role'] ?? '').toString().toUpperCase();
    final displayName =
        (widget.user['full_name'] ?? widget.user['username'] ?? 'User')
            .toString();
    final initials = displayName.trim().isEmpty
        ? 'U'
        : displayName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part.substring(0, 1).toUpperCase())
            .join();
    final extended = MediaQuery.sizeOf(context).width >= 1180;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: extended ? 252 : 82,
            decoration: BoxDecoration(
              color: const Color(0xFF102A43),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      extended ? 20 : 12,
                      20,
                      extended ? 20 : 12,
                      18,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F6690),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                          ),
                        ),
                        if (extended) ...[
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CollegeMS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Management Portal',
                                  style: TextStyle(
                                    color: Color(0xFFB8C7D9),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (extended)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'WORKSPACE',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final selected = i == index;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Tooltip(
                            message: extended ? '' : item.label,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => index = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: EdgeInsets.symmetric(
                                  horizontal: extended ? 14 : 0,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF2F6690)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: extended
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 21,
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFFB8C7D9),
                                    ),
                                    if (extended) ...[
                                      const SizedBox(width: 13),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: TextStyle(
                                            color: selected
                                                ? Colors.white
                                                : const Color(0xFFD7E2EE),
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.onLogout,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: extended ? 14 : 0,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: extended
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.logout_rounded,
                              color: Color(0xFFB8C7D9),
                              size: 20,
                            ),
                            if (extended) ...[
                              const SizedBox(width: 13),
                              const Text(
                                'Sign out',
                                style: TextStyle(
                                  color: Color(0xFFD7E2EE),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 78,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE6EBF1)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[index].label,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'College Management System',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 1,
                        height: 34,
                        color: const Color(0xFFE6EBF1),
                      ),
                      const SizedBox(width: 14),
                      CircleAvatar(
                        radius: 19,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          initials,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (extended)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              role.isEmpty ? 'Authenticated user' : role,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Expanded(child: items[index].page),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Nav {
  final String label;
  final IconData icon;
  final Widget page;

  const _Nav(this.label, this.icon, this.page);
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic> data = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final response = await Api.instance.get('/academic/overview');
      data = Map<String, dynamic>.from(response.data['overview'] ?? {});
    } catch (_) {
      data = {};
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Dashboard',
      subtitle: 'A clear view of your college operations',
      loading: loading,
      onRefresh: load,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF102A43), Color(0xFF2F6690)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome to CollegeMS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage students, academics, faculty, attendance and reports from one professional workspace.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'College Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 3
                : constraints.maxWidth >= 700
                    ? 2
                    : 1;
            final width =
                (constraints.maxWidth - ((columns - 1) * 14)) / columns;

            final stats = [
              ('Students', '${data['students'] ?? 0}', Icons.people_outline),
              ('Faculty', '${data['faculty'] ?? 0}', Icons.badge_outlined),
              ('Courses', '${data['courses'] ?? 0}', Icons.menu_book_outlined),
              (
                'Subjects',
                '${data['subjects'] ?? 0}',
                Icons.library_books_outlined
              ),
              (
                'Departments',
                '${data['departments'] ?? 0}',
                Icons.account_tree_outlined
              ),
              (
                'Branches',
                '${data['branches'] ?? 0}',
                Icons.apartment_outlined
              ),
            ];

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: stats
                  .map(
                    (item) => SizedBox(
                      width: width,
                      child: Stat(
                        title: item.$1,
                        value: item.$2,
                        icon: item.$3,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Wrap(
              spacing: 30,
              runSpacing: 18,
              children: const [
                _DashboardFeature(
                  icon: Icons.people_outline,
                  title: 'Students',
                  description: 'Profiles and academic records',
                ),
                _DashboardFeature(
                  icon: Icons.account_tree_outlined,
                  title: 'Academics',
                  description: 'Departments, courses and subjects',
                ),
                _DashboardFeature(
                  icon: Icons.fact_check_outlined,
                  title: 'Attendance',
                  description: 'Marking, submission and approvals',
                ),
                _DashboardFeature(
                  icon: Icons.bar_chart_outlined,
                  title: 'Reports',
                  description: 'Operational and academic insights',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _DashboardFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 245,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  List<dynamic> students = [];
  List<dynamic> filteredStudents = [];
  bool loading = true;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    searchController.addListener(_filterStudents);
    load();
  }

  @override
  void dispose() {
    searchController.removeListener(_filterStudents);
    searchController.dispose();
    super.dispose();
  }

  void _filterStudents() {
    final query = searchController.text.trim().toLowerCase();
    setState(() {
      filteredStudents = query.isEmpty
          ? List<dynamic>.from(students)
          : students.where((student) {
              final row = Map<String, dynamic>.from(student);
              return '${row['id']}'.toLowerCase().contains(query) ||
                  '${row['name']}'.toLowerCase().contains(query) ||
                  '${row['course']}'.toLowerCase().contains(query);
            }).toList();
    });
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final response = await Api.instance.get('/student/all');
      students = List<dynamic>.from(response.data['students'] ?? []);
      filteredStudents = List<dynamic>.from(students);
    } catch (_) {
      students = [];
      filteredStudents = [];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> saveStudent({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final age = TextEditingController(text: '${existing?['age'] ?? ''}');
    final course = TextEditingController(text: '${existing?['course'] ?? ''}');
    final marks = TextEditingController(text: '${existing?['marks'] ?? ''}');
    String? errorText;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Student' : 'Add Student'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: age,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: course,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Course',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: marks,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Marks',
                          prefixIcon: Icon(Icons.assessment_outlined),
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  icon: Icon(isEdit ? Icons.save_outlined : Icons.add),
                  label: Text(isEdit ? 'Save changes' : 'Create student'),
                  onPressed: () async {
                    final studentName = name.text.trim();
                    final studentAge = int.tryParse(age.text.trim());
                    final studentCourse = course.text.trim();
                    final studentMarks = int.tryParse(marks.text.trim());

                    if (studentName.length < 2) {
                      setDialogState(
                          () => errorText = 'Enter a valid student name.');
                      return;
                    }
                    if (studentAge == null ||
                        studentAge < 1 ||
                        studentAge > 100) {
                      setDialogState(
                          () => errorText = 'Age must be between 1 and 100.');
                      return;
                    }
                    if (studentCourse.length < 2) {
                      setDialogState(() => errorText = 'Enter a valid course.');
                      return;
                    }
                    if (studentMarks == null ||
                        studentMarks < 0 ||
                        studentMarks > 100) {
                      setDialogState(
                          () => errorText = 'Marks must be between 0 and 100.');
                      return;
                    }

                    try {
                      final payload = {
                        'name': studentName,
                        'age': studentAge,
                        'course': studentCourse,
                        'marks': studentMarks,
                      };

                      if (isEdit) {
                        await Api.instance.put(
                          '/student/update/${existing['id']}',
                          payload,
                        );
                      } else {
                        await Api.instance.post('/student/create', payload);
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, true);
                      }
                    } catch (e) {
                      setDialogState(() => errorText =
                          'Unable to save student. Check your access permission.');
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    name.dispose();
    age.dispose();
    course.dispose();
    marks.dispose();

    if (ok == true) await load();
  }

  Future<void> deleteStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete student?'),
        content: Text(
          'This will permanently delete ${student['name'] ?? 'this student'} from the student records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Api.instance.delete('/student/delete/${student['id']}');
      await load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Delete failed. You may not have permission.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final highPerformers = filteredStudents.where((student) {
      final marks = int.tryParse('${student['marks']}') ?? 0;
      return marks >= 75;
    }).length;

    return PageFrame(
      title: 'Students',
      subtitle: 'Student records, academic performance and profile management',
      loading: loading,
      onRefresh: load,
      action: FilledButton.icon(
        onPressed: () => saveStudent(),
        icon: const Icon(Icons.add),
        label: const Text('Add Student'),
      ),
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            Stat(
              title: 'Total students',
              value: '${students.length}',
              icon: Icons.people_outline,
            ),
            Stat(
              title: 'High performers',
              value: '$highPerformers',
              icon: Icons.emoji_events_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search by student ID, name or course...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: searchController.clear,
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 28,
                headingRowHeight: 52,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 72,
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('Age')),
                  DataColumn(label: Text('Course')),
                  DataColumn(label: Text('Marks')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: filteredStudents.map((student) {
                  final row = Map<String, dynamic>.from(student);
                  final marks = int.tryParse('${row['marks']}') ?? 0;
                  final name = '${row['name'] ?? 'Student'}';
                  final initials = name.trim().isEmpty
                      ? 'S'
                      : name.trim().substring(0, 1).toUpperCase();

                  return DataRow(
                    cells: [
                      DataCell(Text('${row['id']}')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              child: Text(initials),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text('${row['age']}')),
                      DataCell(Text('${row['course']}')),
                      DataCell(
                        Text(
                          '$marks',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(
                        Badge(
                          text: marks >= 75 ? 'High performer' : 'Regular',
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit student',
                              onPressed: () => saveStudent(existing: row),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete student',
                              onPressed: () => deleteStudent(row),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        if (!loading && filteredStudents.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No students found.')),
          ),
      ],
    );
  }
}

class AcademicsPage extends StatefulWidget {
  const AcademicsPage({super.key});

  @override
  State<AcademicsPage> createState() => _AcademicsPageState();
}

class _AcademicsPageState extends State<AcademicsPage> {
  int tab = 0;
  bool loading = true;
  final Map<String, List<dynamic>> data = {};

  static const names = [
    'Branches',
    'Departments',
    'Courses',
    'Subjects',
    'Faculty',
    'Enrollments',
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);

    final endpoints = [
      ('Branches', '/academic/branches', 'branches'),
      ('Departments', '/academic/departments', 'departments'),
      ('Courses', '/academic/courses', 'courses'),
      ('Subjects', '/academic/subjects', 'subjects'),
      ('Faculty', '/academic/faculty', 'faculty'),
      ('Enrollments', '/academic/enrollments', 'enrollments'),
    ];

    for (final item in endpoints) {
      try {
        final response = await Api.instance.get(item.$2);
        final body = Map<String, dynamic>.from(response.data ?? {});
        data[item.$1] = List<dynamic>.from(body[item.$3] ?? const []);
      } catch (_) {
        data[item.$1] = data[item.$1] ?? [];
      }
    }

    if (mounted) setState(() => loading = false);
  }

  List<dynamic> get rows => data[names[tab]] ?? [];

  String _text(dynamic value) => value == null ? '' : '$value';

  Future<void> _showForm({Map<String, dynamic>? existing}) async {
    final type = names[tab];
    if (type == 'Enrollments') {
      await _showEnrollmentForm();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _AcademicFormDialog(
        type: type,
        existing: existing,
        branches: data['Branches'] ?? const [],
        departments: data['Departments'] ?? const [],
        courses: data['Courses'] ?? const [],
      ),
    );

    if (result == true) await load();
  }

  Future<void> _showEnrollmentForm() async {
    final students = await _loadStudents();
    final courses = data['Courses'] ?? const [];

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _EnrollmentFormDialog(
        students: students,
        courses: courses,
      ),
    );

    if (result == true) await load();
  }

  Future<List<dynamic>> _loadStudents() async {
    try {
      final response = await Api.instance.get('/student/all');
      return List<dynamic>.from(response.data['students'] ?? const []);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = int.tryParse(_text(row['id']));
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
          'This will remove ${singularName.toLowerCase()} #$id.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Api.instance.delete('/academic/${names[tab].toLowerCase()}/$id');
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiMessage(e))),
      );
    }
  }

  String _apiMessage(dynamic error) {
    try {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) return '${data['message']}';
    } catch (_) {}
    return 'Unable to complete the request.';
  }

  String titleFor(Map<String, dynamic> row) {
    switch (names[tab]) {
      case 'Branches':
        return _text(row['branch_name']);
      case 'Departments':
        return _text(row['department_name']);
      case 'Courses':
        return _text(row['course_name']);
      case 'Subjects':
        return _text(row['subject_name']);
      case 'Faculty':
        return _text(row['faculty_name']);
      case 'Enrollments':
        return _text(row['student_name']);
      default:
        return 'Record';
    }
  }

  String subtitleFor(Map<String, dynamic> row) {
    switch (names[tab]) {
      case 'Branches':
        return '${_text(row['branch_code'])} • ${_text(row['description']).isEmpty ? 'Academic branch' : _text(row['description'])}';
      case 'Departments':
        return '${_text(row['department_code'])} • ${_text(row['branch_name'])}';
      case 'Courses':
        return '${_text(row['course_code'])} • ${_text(row['department_name'])}';
      case 'Subjects':
        return '${_text(row['subject_code'])} • ${_text(row['course_name'])}';
      case 'Faculty':
        return '${_text(row['faculty_code'])} • ${_text(row['designation']).isEmpty ? _text(row['department_name']) : _text(row['designation'])}';
      case 'Enrollments':
        return '${_text(row['course_name'])} • ${_text(row['academic_year'])} • Semester ${_text(row['semester'])}';
      default:
        return '';
    }
  }

  String trailingFor(Map<String, dynamic> row) {
    switch (names[tab]) {
      case 'Branches':
      case 'Departments':
      case 'Courses':
      case 'Subjects':
      case 'Faculty':
        return row['is_active'] == 1 ? 'Active' : 'Inactive';
      case 'Enrollments':
        return _text(row['status']);
      default:
        return '';
    }
  }

  bool get canEdit => names[tab] != 'Enrollments';

  String get singularName {
    switch (names[tab]) {
      case 'Branches':
        return 'Branch';
      case 'Departments':
        return 'Department';
      case 'Courses':
        return 'Course';
      case 'Subjects':
        return 'Subject';
      case 'Faculty':
        return 'Faculty';
      case 'Enrollments':
        return 'Enrollment';
      default:
        return 'Record';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Academic Management',
      subtitle:
          'Branches, departments, courses, subjects, faculty and enrollments',
      loading: loading,
      onRefresh: load,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(
                names.length,
                (i) => ChoiceChip(
                  label: Text('${names[i]} (${(data[names[i]] ?? []).length})'),
                  selected: tab == i,
                  onSelected: (_) => setState(() => tab = i),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                names[tab],
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add),
              label: Text('Add $singularName'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty && !loading)
          const EmptyState(message: 'No records available.')
        else
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final row = Map<String, dynamic>.from(rows[i]);
                final id = int.tryParse(_text(row['id']));
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                  leading: CircleAvatar(
                    child:
                        Text(_text(row['id']).isEmpty ? '-' : _text(row['id'])),
                  ),
                  title: Text(
                    titleFor(row),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(subtitleFor(row)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Badge(text: trailingFor(row)),
                      if (canEdit && id != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _showForm(existing: row),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _delete(row),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _AcademicFormDialog extends StatefulWidget {
  final String type;
  final Map<String, dynamic>? existing;
  final List<dynamic> branches;
  final List<dynamic> departments;
  final List<dynamic> courses;

  const _AcademicFormDialog({
    required this.type,
    required this.existing,
    required this.branches,
    required this.departments,
    required this.courses,
  });

  @override
  State<_AcademicFormDialog> createState() => _AcademicFormDialogState();
}

class _AcademicFormDialogState extends State<_AcademicFormDialog> {
  final code = TextEditingController();
  final name = TextEditingController();
  final description = TextEditingController();
  final duration = TextEditingController();
  final email = TextEditingController();
  final designation = TextEditingController();
  final semester = TextEditingController();
  final credits = TextEditingController();
  int? parentId;
  bool saving = false;

  bool get editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final row = widget.existing ?? const <String, dynamic>{};
    switch (widget.type) {
      case 'Branches':
        code.text = '${row['branch_code'] ?? ''}';
        name.text = '${row['branch_name'] ?? ''}';
        description.text = '${row['description'] ?? ''}';
        break;
      case 'Departments':
        code.text = '${row['department_code'] ?? ''}';
        name.text = '${row['department_name'] ?? ''}';
        description.text = '${row['description'] ?? ''}';
        parentId = _number(row['branch_id']);
        break;
      case 'Courses':
        code.text = '${row['course_code'] ?? ''}';
        name.text = '${row['course_name'] ?? ''}';
        description.text = '${row['description'] ?? ''}';
        duration.text = '${row['duration_years'] ?? ''}';
        parentId = _number(row['department_id']);
        break;
      case 'Subjects':
        code.text = '${row['subject_code'] ?? ''}';
        name.text = '${row['subject_name'] ?? ''}';
        semester.text = '${row['semester'] ?? ''}';
        credits.text = '${row['credits'] ?? 3}';
        parentId = _number(row['course_id']);
        break;
      case 'Faculty':
        code.text = '${row['faculty_code'] ?? ''}';
        name.text = '${row['faculty_name'] ?? ''}';
        email.text = '${row['email'] ?? ''}';
        designation.text = '${row['designation'] ?? ''}';
        parentId = _number(row['department_id']);
        break;
    }
  }

  int? _number(dynamic value) => int.tryParse('$value');

  @override
  void dispose() {
    code.dispose();
    name.dispose();
    description.dispose();
    duration.dispose();
    email.dispose();
    designation.dispose();
    semester.dispose();
    credits.dispose();
    super.dispose();
  }

  String _singularType() {
    switch (widget.type) {
      case 'Branches':
        return 'Branch';
      case 'Departments':
        return 'Department';
      case 'Courses':
        return 'Course';
      case 'Subjects':
        return 'Subject';
      case 'Faculty':
        return 'Faculty';
      default:
        return 'Record';
    }
  }

  String get endpoint {
    switch (widget.type) {
      case 'Branches':
        return '/academic/branches';
      case 'Departments':
        return '/academic/departments';
      case 'Courses':
        return '/academic/courses';
      case 'Subjects':
        return '/academic/subjects';
      case 'Faculty':
        return '/academic/faculty';
      default:
        return '/academic';
    }
  }

  Map<String, dynamic> payload() {
    switch (widget.type) {
      case 'Branches':
        return {
          'branch_code': code.text,
          'branch_name': name.text,
          'description': description.text
        };
      case 'Departments':
        return {
          'department_code': code.text,
          'department_name': name.text,
          'branch_id': parentId,
          'description': description.text
        };
      case 'Courses':
        return {
          'course_code': code.text,
          'course_name': name.text,
          'department_id': parentId,
          'duration_years': int.tryParse(duration.text),
          'description': description.text
        };
      case 'Subjects':
        return {
          'subject_code': code.text,
          'subject_name': name.text,
          'course_id': parentId,
          'semester': int.tryParse(semester.text),
          'credits': int.tryParse(credits.text)
        };
      case 'Faculty':
        return {
          'faculty_code': code.text,
          'faculty_name': name.text,
          'email': email.text,
          'department_id': parentId,
          'designation': designation.text
        };
      default:
        return {};
    }
  }

  Future<void> save() async {
    if (code.text.trim().isEmpty || name.text.trim().isEmpty) return;
    if (widget.type != 'Branches' && parentId == null) return;
    if (widget.type == 'Courses' && int.tryParse(duration.text) == null) return;
    if (widget.type == 'Subjects' && int.tryParse(semester.text) == null)
      return;

    setState(() => saving = true);
    try {
      final id = int.tryParse('${widget.existing?['id']}');
      if (editing && id != null) {
        await Api.instance.put('$endpoint/$id', payload());
      } else {
        await Api.instance.post(endpoint, payload());
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(e))),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _message(dynamic error) {
    try {
      final value = error.response?.data;
      if (value is Map && value['message'] != null)
        return '${value['message']}';
    } catch (_) {}
    return 'Unable to save the record.';
  }

  List<DropdownMenuItem<int>> _items(
      List<dynamic> source, String idKey, String labelKey) {
    return source
        .map((item) {
          final row = Map<String, dynamic>.from(item);
          final id = _number(row[idKey]);
          return DropdownMenuItem<int>(
              value: id, child: Text('${row[labelKey] ?? '-'}'));
        })
        .where((item) => item.value != null)
        .toList();
  }

  Widget _field(TextEditingController controller, String label,
      {bool required = false, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: required ? '$label *' : label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = switch (widget.type) {
      'Departments' => _items(widget.branches, 'id', 'branch_name'),
      'Courses' => _items(widget.departments, 'id', 'department_name'),
      'Subjects' => _items(widget.courses, 'id', 'course_name'),
      'Faculty' => _items(widget.departments, 'id', 'department_name'),
      _ => <DropdownMenuItem<int>>[],
    };

    final parentLabel = switch (widget.type) {
      'Departments' => 'Branch',
      'Courses' => 'Department',
      'Subjects' => 'Course',
      'Faculty' => 'Department',
      _ => '',
    };

    return AlertDialog(
      title: Text('${editing ? 'Edit' : 'Add'} ${_singularType()}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(code, 'Code', required: true),
              _field(name, 'Name', required: true),
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<int>(
                    initialValue: items.any((item) => item.value == parentId)
                        ? parentId
                        : null,
                    items: items,
                    onChanged: (value) => setState(() => parentId = value),
                    decoration: InputDecoration(labelText: '$parentLabel *'),
                  ),
                ),
              if (widget.type == 'Courses')
                _field(duration, 'Duration (years)',
                    required: true, keyboard: TextInputType.number),
              if (widget.type == 'Subjects') ...[
                _field(semester, 'Semester',
                    required: true, keyboard: TextInputType.number),
                _field(credits, 'Credits', keyboard: TextInputType.number),
              ],
              if (widget.type == 'Faculty') ...[
                _field(email, 'Email', keyboard: TextInputType.emailAddress),
                _field(designation, 'Designation'),
              ],
              if (widget.type == 'Branches' ||
                  widget.type == 'Departments' ||
                  widget.type == 'Courses')
                _field(description, 'Description'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: Text(editing ? 'Save Changes' : 'Save'),
        ),
      ],
    );
  }
}

class _EnrollmentFormDialog extends StatefulWidget {
  final List<dynamic> students;
  final List<dynamic> courses;

  const _EnrollmentFormDialog({required this.students, required this.courses});

  @override
  State<_EnrollmentFormDialog> createState() => _EnrollmentFormDialogState();
}

class _EnrollmentFormDialogState extends State<_EnrollmentFormDialog> {
  int? studentId;
  int? courseId;
  final year = TextEditingController(text: '2026-27');
  final semester = TextEditingController(text: '1');
  final status = TextEditingController(text: 'ACTIVE');
  bool saving = false;

  int? _number(dynamic value) => int.tryParse('$value');

  @override
  void dispose() {
    year.dispose();
    semester.dispose();
    status.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<int>> _items(
      List<dynamic> source, String idKey, String labelKey) {
    return source
        .map((item) {
          final row = Map<String, dynamic>.from(item);
          return DropdownMenuItem<int>(
            value: _number(row[idKey]),
            child: Text('${row[labelKey] ?? '-'}'),
          );
        })
        .where((item) => item.value != null)
        .toList();
  }

  Future<void> save() async {
    final semesterValue = int.tryParse(semester.text);
    if (studentId == null ||
        courseId == null ||
        year.text.trim().isEmpty ||
        semesterValue == null) return;

    setState(() => saving = true);
    try {
      await Api.instance.post('/academic/enrollments', {
        'student_id': studentId,
        'course_id': courseId,
        'academic_year': year.text.trim(),
        'semester': semesterValue,
        'status': status.text.trim().toUpperCase(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_message(e))),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _message(dynamic error) {
    try {
      final value = error.response?.data;
      if (value is Map && value['message'] != null)
        return '${value['message']}';
    } catch (_) {}
    return 'Unable to create enrollment.';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Enrollment'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: studentId,
              items: _items(widget.students, 'id', 'name'),
              onChanged: (value) => setState(() => studentId = value),
              decoration: const InputDecoration(labelText: 'Student *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: courseId,
              items: _items(widget.courses, 'id', 'course_name'),
              onChanged: (value) => setState(() => courseId = value),
              decoration: const InputDecoration(labelText: 'Course *'),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: year,
                decoration:
                    const InputDecoration(labelText: 'Academic year *')),
            const SizedBox(height: 12),
            TextField(
                controller: semester,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Semester *')),
            const SizedBox(height: 12),
            TextField(
                controller: status,
                decoration: const InputDecoration(labelText: 'Status')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: const Text('Save Enrollment'),
        ),
      ],
    );
  }
}

class AttendancePage extends StatefulWidget {
  final String role;

  const AttendancePage({
    super.key,
    this.role = '',
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<dynamic> rows = [];
  bool loading = true;
  String? errorMessage;

  String get role => widget.role.toUpperCase();
  bool get isStudent => role == 'STUDENT';
  bool get isFaculty => role == 'FACULTY';
  bool get isHod => role == 'HOD';
  bool get isAdmin => role == 'ADMIN' || role == 'SUPER_ADMIN';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final response = await Api.instance.get('/attendance/all');
      final data = response.data;
      rows = data is Map<String, dynamic>
          ? List<dynamic>.from(data['attendance'] ?? [])
          : [];
    } catch (e) {
      rows = [];
      errorMessage = _readError(e);
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _showCreateAttendanceDialog() async {
    if (isStudent || isHod) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _AttendanceCreateDialog(),
    );

    if (result == true) {
      await load();
    }
  }

  Future<void> transition(int id, String action, String message) async {
    try {
      await Api.instance.post('/attendance/$id/$action', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_readError(e))),
      );
    }
  }

  String _readError(Object error) {
    try {
      final data = (error as dynamic).response?.data;
      if (data is Map && data['message'] != null) {
        return '${data['message']}';
      }
    } catch (_) {}
    return 'Unable to complete attendance request.';
  }

  List<PopupMenuEntry<String>> actionsFor(Map<String, dynamic> row) {
    final id = int.tryParse('${row['id']}');
    if (id == null || isStudent) return const [];

    final status = '${row['status'] ?? ''}'.toUpperCase();
    final actions = <PopupMenuEntry<String>>[];

    if (isFaculty || isAdmin) {
      if (status.isEmpty ||
          status == 'DRAFT' ||
          status == 'PENDING' ||
          status == 'REJECTED') {
        actions.add(
          PopupMenuItem(
            value: 'mark:$id',
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.fact_check_outlined),
              title: Text('Mark attendance'),
            ),
          ),
        );
      }

      if (status == 'MARKED' || status == 'DRAFT') {
        actions.add(
          PopupMenuItem(
            value: 'submit:$id',
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.send_outlined),
              title: Text('Submit attendance'),
            ),
          ),
        );
      }
    }

    if (isHod || isAdmin) {
      if (status == 'SUBMITTED' || status == 'PENDING_APPROVAL') {
        actions.add(
          PopupMenuItem(
            value: 'approve:$id',
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle_outline),
              title: Text('Approve'),
            ),
          ),
        );
        actions.add(
          PopupMenuItem(
            value: 'reject:$id',
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cancel_outlined),
              title: Text('Reject'),
            ),
          ),
        );
      }
    }

    if (isAdmin && actions.isEmpty) {
      actions.addAll([
        PopupMenuItem(
          value: 'mark:$id',
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.fact_check_outlined),
            title: Text('Mark attendance'),
          ),
        ),
        PopupMenuItem(
          value: 'submit:$id',
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.send_outlined),
            title: Text('Submit attendance'),
          ),
        ),
        PopupMenuItem(
          value: 'approve:$id',
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.check_circle_outline),
            title: Text('Approve'),
          ),
        ),
        PopupMenuItem(
          value: 'reject:$id',
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.cancel_outlined),
            title: Text('Reject'),
          ),
        ),
      ]);
    }

    return actions;
  }

  String statusLabel(dynamic value) {
    final status =
        '${value ?? 'UNKNOWN'}'.replaceAll('_', ' ').trim().toLowerCase();
    if (status.isEmpty) return 'Unknown';
    return status
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  IconData statusIcon(dynamic value) {
    switch ('${value ?? ''}'.toUpperCase()) {
      case 'APPROVED':
        return Icons.check_circle_outline;
      case 'REJECTED':
        return Icons.cancel_outlined;
      case 'SUBMITTED':
      case 'PENDING_APPROVAL':
        return Icons.hourglass_top_rounded;
      case 'MARKED':
        return Icons.fact_check_outlined;
      default:
        return Icons.schedule_outlined;
    }
  }

  Widget statusBadge(BuildContext context, dynamic value) {
    final status = '${value ?? ''}'.toUpperCase();
    late Color background;
    late Color foreground;

    switch (status) {
      case 'APPROVED':
        background = Colors.green.withValues(alpha: 0.12);
        foreground = Colors.green.shade700;
        break;
      case 'REJECTED':
        background = Colors.red.withValues(alpha: 0.12);
        foreground = Colors.red.shade700;
        break;
      case 'SUBMITTED':
      case 'PENDING_APPROVAL':
        background = Colors.orange.withValues(alpha: 0.14);
        foreground = Colors.orange.shade800;
        break;
      case 'MARKED':
        background = Colors.blue.withValues(alpha: 0.12);
        foreground = Colors.blue.shade700;
        break;
      default:
        background = Colors.grey.withValues(alpha: 0.12);
        foreground = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(value), size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(
            statusLabel(value),
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = rows.length;
    final approved = rows.where((item) {
      final row = Map<String, dynamic>.from(item);
      return '${row['status'] ?? ''}'.toUpperCase() == 'APPROVED';
    }).length;
    final pending = rows.where((item) {
      final row = Map<String, dynamic>.from(item);
      final status = '${row['status'] ?? ''}'.toUpperCase();
      return status == 'SUBMITTED' || status == 'PENDING_APPROVAL';
    }).length;

    return PageFrame(
      title: 'Attendance',
      subtitle: isStudent
          ? 'Your attendance records'
          : isHod
              ? 'Attendance review and department approvals'
              : isFaculty
                  ? 'Attendance marking and submission'
                  : 'Attendance records and workflow management',
      loading: loading,
      onRefresh: load,
      children: [
        if (isFaculty || isAdmin)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: loading ? null : _showCreateAttendanceDialog,
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('Create Attendance Record'),
            ),
          ),
        if (isFaculty || isAdmin) const SizedBox(height: 16),
        if (errorMessage != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(child: Text(errorMessage!)),
                  IconButton(
                    tooltip: 'Retry',
                    onPressed: load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
        if (!loading && errorMessage == null) ...[
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _AttendanceMetric(
                title: 'Total Records',
                value: '$total',
                icon: Icons.fact_check_outlined,
              ),
              _AttendanceMetric(
                title: 'Approved',
                value: '$approved',
                icon: Icons.check_circle_outline,
              ),
              _AttendanceMetric(
                title: 'Pending',
                value: '$pending',
                icon: Icons.pending_actions_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        Card(
          clipBehavior: Clip.antiAlias,
          child: rows.isEmpty && !loading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: EmptyState(
                    message: 'No attendance records available.',
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 52,
                    dataRowMinHeight: 62,
                    dataRowMaxHeight: 72,
                    columns: [
                      const DataColumn(label: Text('Student')),
                      const DataColumn(label: Text('Subject')),
                      const DataColumn(label: Text('Course')),
                      const DataColumn(label: Text('Date')),
                      const DataColumn(label: Text('Status')),
                      if (!isStudent) const DataColumn(label: Text('Faculty')),
                      if (!isStudent) const DataColumn(label: Text('Actions')),
                    ],
                    rows: rows.map((item) {
                      final row = Map<String, dynamic>.from(item);
                      final id = int.tryParse('${row['id']}');
                      final actions = actionsFor(row);

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircleAvatar(
                                  radius: 17,
                                  child: Icon(Icons.person_outline, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${row['student_name'] ?? '-'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text('${row['subject_name'] ?? '-'}')),
                          DataCell(Text('${row['course_name'] ?? '-'}')),
                          DataCell(Text('${row['attendance_date'] ?? '-'}')),
                          DataCell(statusBadge(context, row['status'])),
                          if (!isStudent)
                            DataCell(Text('${row['faculty_name'] ?? '-'}')),
                          if (!isStudent)
                            DataCell(
                              actions.isEmpty || id == null
                                  ? const SizedBox.shrink()
                                  : PopupMenuButton<String>(
                                      tooltip: 'Attendance actions',
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        final parts = value.split(':');
                                        if (parts.length != 2) return;
                                        final actionId = int.tryParse(parts[1]);
                                        if (actionId == null) return;

                                        final message = switch (parts[0]) {
                                          'mark' =>
                                            'Attendance marked successfully.',
                                          'submit' =>
                                            'Attendance submitted successfully.',
                                          'approve' =>
                                            'Attendance approved successfully.',
                                          'reject' =>
                                            'Attendance rejected successfully.',
                                          _ =>
                                            'Attendance updated successfully.',
                                        };

                                        transition(actionId, parts[0], message);
                                      },
                                      itemBuilder: (_) => actions,
                                    ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          isStudent
              ? 'Attendance visibility is controlled by your account scope.'
              : 'Available workflow actions are controlled by your role and server authorization rules.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AttendanceCreateDialog extends StatefulWidget {
  const _AttendanceCreateDialog();

  @override
  State<_AttendanceCreateDialog> createState() =>
      _AttendanceCreateDialogState();
}

class _AttendanceCreateDialogState extends State<_AttendanceCreateDialog> {
  List<dynamic> enrollments = [];
  List<dynamic> subjects = [];
  int? enrollmentId;
  int? subjectId;
  String status = 'PRESENT';
  DateTime selectedDate = DateTime.now();
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final results = await Future.wait([
        Api.instance.get('/academic/enrollments'),
        Api.instance.get('/academic/subjects'),
      ]);

      final enrollmentBody = Map<String, dynamic>.from(results[0].data ?? {});
      final subjectBody = Map<String, dynamic>.from(results[1].data ?? {});

      enrollments =
          List<dynamic>.from(enrollmentBody['enrollments'] ?? const []);
      subjects = List<dynamic>.from(subjectBody['subjects'] ?? const []);

      if (enrollments.isEmpty) {
        error = 'Create an active enrollment first from Academic Management.';
      }
    } catch (e) {
      error = _dialogMessage(e);
    }

    if (mounted) setState(() => loading = false);
  }

  int? _id(dynamic value) => int.tryParse('$value');

  String _dialogMessage(dynamic error) {
    try {
      final value = error.response?.data;
      if (value is Map && value['message'] != null)
        return '${value['message']}';
    } catch (_) {}
    return 'Unable to load attendance options.';
  }

  String _dateValue() {
    final y = selectedDate.year.toString().padLeft(4, '0');
    final m = selectedDate.month.toString().padLeft(2, '0');
    final d = selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> save() async {
    if (enrollmentId == null || subjectId == null) {
      setState(() => error = 'Select both an enrollment and a subject.');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await Api.instance.post('/attendance', {
        'enrollment_id': enrollmentId,
        'subject_id': subjectId,
        'attendance_date': _dateValue(),
        'status': status,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = _dialogMessage(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Attendance Record'),
      content: SizedBox(
        width: 520,
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: enrollmentId,
                      items: enrollments
                          .map((item) {
                            final row = Map<String, dynamic>.from(item);
                            final id = _id(row['id']);
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(
                                '#$id • ${row['student_name'] ?? '-'} • ${row['course_name'] ?? '-'} • Sem ${row['semester'] ?? '-'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          })
                          .where((item) => item.value != null)
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              setState(() => enrollmentId = value);
                            },
                      decoration:
                          const InputDecoration(labelText: 'Enrollment *'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: subjectId,
                      items: subjects
                          .map((item) {
                            final row = Map<String, dynamic>.from(item);
                            final id = _id(row['id']);
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(
                                '${row['subject_code'] ?? '-'} • ${row['subject_name'] ?? '-'} • ${row['course_name'] ?? '-'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          })
                          .where((item) => item.value != null)
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              setState(() => subjectId = value);
                            },
                      decoration: const InputDecoration(labelText: 'Subject *'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Attendance date'),
                      subtitle: Text(_dateValue()),
                      trailing: TextButton(
                        onPressed: saving
                            ? null
                            : () async {
                                final value = await showDatePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                  initialDate: selectedDate,
                                );
                                if (value != null && mounted) {
                                  setState(() => selectedDate = value);
                                }
                              },
                        child: const Text('Change'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      items: const [
                        DropdownMenuItem(
                            value: 'PRESENT', child: Text('Present')),
                        DropdownMenuItem(
                            value: 'ABSENT', child: Text('Absent')),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              setState(() => status = value ?? 'PRESENT');
                            },
                      decoration:
                          const InputDecoration(labelText: 'Attendance status'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: loading || saving || enrollments.isEmpty ? null : save,
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: const Text('Create Record'),
        ),
      ],
    );
  }
}

class _AttendanceMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _AttendanceMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FacultyPage extends StatefulWidget {
  const FacultyPage({super.key});

  @override
  State<FacultyPage> createState() => _FacultyPageState();
}

class _FacultyPageState extends State<FacultyPage> {
  List<dynamic> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final response = await Api.instance.get('/academic/faculty');
      rows = List<dynamic>.from(response.data['faculty'] ?? []);
    } catch (_) {
      rows = [];
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Faculty',
      subtitle: 'Faculty directory and department assignments',
      loading: loading,
      onRefresh: load,
      children: [
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final row = Map<String, dynamic>.from(rows[i]);
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text('${row['faculty_name']}'),
                subtitle: Text(
                    '${row['designation'] ?? 'Faculty'} • ${row['department_name'] ?? ''}'),
                trailing: Text('${row['faculty_code'] ?? ''}'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  Future<void> _openReport(
    BuildContext context,
    String title,
    String endpoint,
    String listKey,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final response = await Api.instance.get(endpoint);

      if (!context.mounted) return;
      Navigator.of(context).pop();

      final body = Map<String, dynamic>.from(response.data ?? {});
      final rows = List<dynamic>.from(body[listKey] ?? const []);

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 700,
            height: 450,
            child: rows.isEmpty
                ? const Center(
                    child: Text('No records available for this report.'),
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final row = Map<String, dynamic>.from(rows[index] as Map);

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${index + 1}'),
                        ),
                        title: Text(_reportTitle(row)),
                        subtitle: Text(_reportSubtitle(row)),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      Navigator.of(context).pop();

      String message = 'Unable to load report.';

      try {
        final dynamic dioError = e;
        final dynamic data = dioError.response?.data;
        if (data is Map) {
          message = '${data['message'] ?? data['error'] ?? message}';
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _reportTitle(Map<String, dynamic> row) {
    return '${row['name'] ?? row['student_name'] ?? row['faculty_name'] ?? row['department_name'] ?? row['course_name'] ?? row['subject_name'] ?? row['faculty_code'] ?? row['department_code'] ?? 'Record'}';
  }

  String _reportSubtitle(Map<String, dynamic> row) {
    final parts = <String>[];

    if (row['student_name'] != null) {
      parts.add('Student: ${row['student_name']}');
    }

    if (row['faculty_name'] != null) {
      parts.add('Faculty: ${row['faculty_name']}');
    }

    if (row['department_name'] != null) {
      parts.add('Department: ${row['department_name']}');
    }

    if (row['course_name'] != null) {
      parts.add('Course: ${row['course_name']}');
    }

    if (row['status'] != null) {
      parts.add('Status: ${row['status']}');
    }

    if (row['marks'] != null) {
      parts.add('Marks: ${row['marks']}');
    }

    if (row['attendance_date'] != null) {
      parts.add('Date: ${row['attendance_date']}');
    }

    if (row['designation'] != null) {
      parts.add('Designation: ${row['designation']}');
    }

    return parts.isEmpty ? 'College Management record' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Reports',
      subtitle: 'Operational reporting workspace',
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            ReportCard(
              title: 'Student Report',
              icon: Icons.people_outline,
              onOpen: () => _openReport(
                context,
                'Student Report',
                '/student/all',
                'students',
              ),
            ),
            ReportCard(
              title: 'Attendance Report',
              icon: Icons.fact_check_outlined,
              onOpen: () => _openReport(
                context,
                'Attendance Report',
                '/attendance/all',
                'attendance',
              ),
            ),
            ReportCard(
              title: 'Department Report',
              icon: Icons.account_tree_outlined,
              onOpen: () => _openReport(
                context,
                'Department Report',
                '/academic/departments',
                'departments',
              ),
            ),
            ReportCard(
              title: 'Faculty Report',
              icon: Icons.badge_outlined,
              onOpen: () => _openReport(
                context,
                'Faculty Report',
                '/academic/faculty',
                'faculty',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Reports are organized around students, attendance, '
              'academic structure and faculty operations.',
            ),
          ),
        ),
      ],
    );
  }
}

class ReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onOpen;

  const ReportCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text('Open report workspace'),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onOpen,
                child: const Text('Open'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminPage extends StatefulWidget {
  final String role;

  const AdminPage({super.key, this.role = 'ADMIN'});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<dynamic> users = [];
  List<dynamic> roles = [];
  bool loading = true;
  bool saving = false;
  String? errorMessage;

  final searchController = TextEditingController();
  final usernameController = TextEditingController();
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();

  int? selectedCreateRoleId;
  int? selectedUserId;
  int? selectedAssignRoleId;

  bool get isSuperAdmin => widget.role.toUpperCase() == 'SUPER_ADMIN';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    usernameController.dispose();
    fullNameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        Api.instance.get('/users'),
        Api.instance.get('/rbac/role-list'),
      ]);

      final usersBody = Map<String, dynamic>.from(results[0].data ?? {});
      final rolesBody = Map<String, dynamic>.from(results[1].data ?? {});

      users = List<dynamic>.from(usersBody['users'] ?? []);
      roles = List<dynamic>.from(rolesBody['roles'] ?? []);
    } catch (e) {
      users = [];
      roles = [];
      errorMessage = _errorMessage(e);
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> searchUsers() async {
    final query = searchController.text.trim();

    if (query.isEmpty) {
      await load();
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await Api.instance.get(
        '/users/search',
        {'q': query},
      );

      final body = Map<String, dynamic>.from(response.data ?? {});
      users = List<dynamic>.from(body['users'] ?? []);
    } catch (e) {
      errorMessage = _errorMessage(e);
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> createUser() async {
    final username = usernameController.text.trim();
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();

    if (username.isEmpty || fullName.isEmpty) {
      _showMessage('Username and full name are required.');
      return;
    }

    setState(() => saving = true);

    try {
      await Api.instance.post(
        '/users/create',
        {
          'username': username,
          'full_name': fullName,
          'email': email.isEmpty ? null : email,
          'role_id': selectedCreateRoleId,
        },
      );

      usernameController.clear();
      fullNameController.clear();
      emailController.clear();
      selectedCreateRoleId = null;

      _showMessage('User created successfully.');
      await load();
    } catch (e) {
      _showMessage(_errorMessage(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> assignRole() async {
    if (!isSuperAdmin) {
      _showMessage('Only SUPER_ADMIN can assign roles.');
      return;
    }

    if (selectedUserId == null || selectedAssignRoleId == null) {
      _showMessage('Select a user and a role first.');
      return;
    }

    setState(() => saving = true);

    try {
      await Api.instance.put(
        '/users/$selectedUserId/role',
        {'role_id': selectedAssignRoleId},
      );

      _showMessage('Role assigned successfully.');
      selectedUserId = null;
      selectedAssignRoleId = null;
      await load();
    } catch (e) {
      _showMessage(_errorMessage(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _errorMessage(Object error) {
    try {
      final dynamic dioError = error;
      final dynamic data = dioError.response?.data;
      if (data is Map) {
        final message = data['message'] ?? data['error'];
        if (message != null) return message.toString();
      }
      final dynamic message = dioError.message;
      if (message != null) return message.toString();
    } catch (_) {}

    return error.toString().replaceFirst('Exception: ', '');
  }

  String roleName(dynamic roleId) {
    final id = int.tryParse('${roleId ?? ''}');
    final role = roles.where((item) {
      final row = Map<String, dynamic>.from(item);
      return int.tryParse('${row['id']}') == id;
    }).toList();

    if (role.isEmpty) return 'UNASSIGNED';
    return '${Map<String, dynamic>.from(role.first)['role_name'] ?? 'UNASSIGNED'}';
  }

  Widget roleDropdown({
    required int? value,
    required ValueChanged<int?> onChanged,
    String label = 'Role',
  }) {
    final validValue = roles.any(
      (item) =>
          int.tryParse('${Map<String, dynamic>.from(item)['id']}') == value,
    )
        ? value
        : null;

    return DropdownButtonFormField<int>(
      initialValue: validValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.badge_outlined),
      ),
      items: roles
          .map((item) {
            final row = Map<String, dynamic>.from(item);
            final id = int.tryParse('${row['id']}');
            if (id == null) return null;
            return DropdownMenuItem<int>(
              value: id,
              child: Text('${row['role_name'] ?? 'ROLE'}'),
            );
          })
          .whereType<DropdownMenuItem<int>>()
          .toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Administration',
      subtitle: 'Manage college users and account roles',
      loading: loading,
      onRefresh: load,
      children: [
        if (errorMessage != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(errorMessage!)),
                  IconButton(
                    onPressed: load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            Stat(
              title: 'Users',
              value: '${users.length}',
              icon: Icons.people_outline,
            ),
            Stat(
              title: 'Roles',
              value: '${roles.length}',
              icon: Icons.groups_2_outlined,
            ),
            Stat(
              title: 'Active Users',
              value:
                  '${users.where((item) => Map<String, dynamic>.from(item)['is_active'] == 1).length}',
              icon: Icons.verified_user_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create User',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                const Text('Add a new college system account.'),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 850;
                    final width = wide
                        ? (constraints.maxWidth - 24) / 3
                        : constraints.maxWidth;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: width,
                          child: TextField(
                            controller: usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: TextField(
                            controller: fullNameController,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: roleDropdown(
                            value: selectedCreateRoleId,
                            label: 'Initial role',
                            onChanged: (value) {
                              setState(() => selectedCreateRoleId = value);
                            },
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: FilledButton.icon(
                            onPressed: saving ? null : createUser,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: Text(saving ? 'Saving...' : 'Create User'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (isSuperAdmin)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign Role',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Change the role of an existing user.'),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth >= 850
                          ? (constraints.maxWidth - 24) / 3
                          : constraints.maxWidth;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: width,
                            child: DropdownButtonFormField<int>(
                              initialValue: users.any(
                                (item) =>
                                    int.tryParse(
                                      '${Map<String, dynamic>.from(item)['id']}',
                                    ) ==
                                    selectedUserId,
                              )
                                  ? selectedUserId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Select user',
                                prefixIcon: Icon(Icons.person_search_outlined),
                              ),
                              items: users
                                  .map((item) {
                                    final row = Map<String, dynamic>.from(item);
                                    final id = int.tryParse('${row['id']}');
                                    if (id == null) return null;
                                    return DropdownMenuItem<int>(
                                      value: id,
                                      child: Text(
                                        '${row['full_name'] ?? row['username'] ?? 'User'}',
                                      ),
                                    );
                                  })
                                  .whereType<DropdownMenuItem<int>>()
                                  .toList(),
                              onChanged: (value) {
                                setState(() => selectedUserId = value);
                              },
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: roleDropdown(
                              value: selectedAssignRoleId,
                              label: 'New role',
                              onChanged: (value) {
                                setState(() => selectedAssignRoleId = value);
                              },
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: FilledButton.icon(
                              onPressed: saving ? null : assignRole,
                              icon: const Icon(Icons.swap_horiz),
                              label: const Text('Assign Role'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Users',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        controller: searchController,
                        onSubmitted: (_) => searchUsers(),
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            onPressed: searchUsers,
                            icon: const Icon(Icons.arrow_forward),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                users.isEmpty
                    ? const EmptyState(message: 'No users found.')
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 50,
                          dataRowMinHeight: 62,
                          dataRowMaxHeight: 70,
                          columns: const [
                            DataColumn(label: Text('User')),
                            DataColumn(label: Text('Username')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: users.map((item) {
                            final row = Map<String, dynamic>.from(item);
                            final active = row['is_active'] == 1 ||
                                row['is_active'] == true;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircleAvatar(
                                        radius: 17,
                                        child: Icon(Icons.person_outline,
                                            size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${row['full_name'] ?? '-'}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text('${row['username'] ?? '-'}')),
                                DataCell(Text('${row['email'] ?? '-'}')),
                                DataCell(Badge(
                                    text:
                                        '${row['role_name'] ?? roleName(row['role_id'])}')),
                                DataCell(
                                  Badge(
                                    text: active ? 'ACTIVE' : 'INACTIVE',
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  List<dynamic> matrix = [];
  List<dynamic> roles = [];
  List<dynamic> doctypes = [];
  List<dynamic> permissions = [];
  bool loading = true;
  String? errorMessage;

  int? selectedRoleId;
  int? selectedDoctypeId;
  int? selectedPermissionId;
  String selectedScope = 'ALL';

  final actionController = TextEditingController(
    text: 'mark_attendance',
  );
  final actionDoctypeController = TextEditingController(
    text: 'Attendance',
  );
  final actionRecordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    actionController.dispose();
    actionDoctypeController.dispose();
    actionRecordController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final result = await Future.wait([
        Api.instance.get('/rbac/roles'),
        Api.instance.get('/rbac/role-list'),
        Api.instance.get('/rbac/doctypes'),
        Api.instance.get('/rbac/permissions'),
      ]);

      matrix = List<dynamic>.from(result[0].data['roles'] ?? []);
      roles = List<dynamic>.from(result[1].data['roles'] ?? []);
      doctypes = List<dynamic>.from(result[2].data['doctypes'] ?? []);
      permissions = List<dynamic>.from(result[3].data['permissions'] ?? []);

      if (selectedRoleId == null && roles.isNotEmpty) {
        selectedRoleId = int.tryParse('${roles.first['id']}');
      }
      if (selectedDoctypeId == null && doctypes.isNotEmpty) {
        selectedDoctypeId = int.tryParse('${doctypes.first['id']}');
      }
      if (selectedPermissionId == null && permissions.isNotEmpty) {
        selectedPermissionId = int.tryParse('${permissions.first['id']}');
      }
    } catch (e) {
      matrix = [];
      roles = [];
      doctypes = [];
      permissions = [];
      errorMessage = _errorMessage(e);
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        return '${data['message'] ?? data['error'] ?? error.message ?? 'Unable to load security data.'}';
      }
      return error.message ?? 'Unable to load security data.';
    }
    return 'Unable to load security data.';
  }

  Future<void> assignPermission() async {
    if (selectedRoleId == null ||
        selectedDoctypeId == null ||
        selectedPermissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select role, DocType and permission.'),
        ),
      );
      return;
    }

    try {
      await Api.instance.post(
        '/rbac/role-permissions/create',
        {
          'role_id': selectedRoleId,
          'doctype_id': selectedDoctypeId,
          'permission_id': selectedPermissionId,
          'scope': selectedScope,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission assigned successfully.'),
        ),
      );

      await load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
    }
  }

  Future<void> checkPermission() async {
    final role = roles.firstWhere(
      (item) => '${item['id']}' == '${selectedRoleId ?? ''}',
      orElse: () => null,
    );

    final doctype = doctypes.firstWhere(
      (item) => '${item['id']}' == '${selectedDoctypeId ?? ''}',
      orElse: () => null,
    );

    final permission = permissions.firstWhere(
      (item) => '${item['id']}' == '${selectedPermissionId ?? ''}',
      orElse: () => null,
    );

    if (role == null || doctype == null || permission == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select all access-control fields.')),
      );
      return;
    }

    try {
      final response = await Api.instance.get(
        '/rbac/check',
        {
          'doctype': doctype['doctype_name'],
          'permission': permission['action_name'],
        },
      );

      if (!mounted) return;

      final authorization = response.data['authorization'];
      final allowed =
          authorization is Map ? authorization['allowed'] == true : false;

      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Access Check'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Role: ${role['role_name']}'),
              Text('DocType: ${doctype['doctype_name']}'),
              Text('Permission: ${permission['action_name']}'),
              const SizedBox(height: 14),
              Badge(text: allowed ? 'ALLOWED' : 'DENIED'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
    }
  }

  Future<void> checkBusinessAction() async {
    final action = actionController.text.trim();
    final doctype = actionDoctypeController.text.trim();
    final recordId = actionRecordController.text.trim();

    if (action.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a business action.')),
      );
      return;
    }

    try {
      final query = <String, dynamic>{
        'action': action,
        if (doctype.isNotEmpty) 'doctype': doctype,
        if (recordId.isNotEmpty) 'record_id': recordId,
      };

      final response = await Api.instance.get(
        '/rbac/business-action/check',
        query,
      );

      if (!mounted) return;

      final authorization = response.data['authorization'];
      final allowed =
          authorization is Map ? authorization['allowed'] == true : false;

      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Business Action Check'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Action: $action'),
              if (doctype.isNotEmpty) Text('DocType: $doctype'),
              if (recordId.isNotEmpty) Text('Record: $recordId'),
              const SizedBox(height: 14),
              Badge(text: allowed ? 'AUTHORIZED' : 'DENIED'),
              const SizedBox(height: 12),
              if (authorization is Map && authorization['reason'] != null)
                Text(
                  'Reason: ${authorization['reason']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
    }
  }

  String roleName(dynamic id) {
    final item = roles.cast<dynamic>().firstWhere(
          (value) => '${value['id']}' == '$id',
          orElse: () => null,
        );
    return '${item?['role_name'] ?? id}';
  }

  String doctypeName(dynamic id) {
    final item = doctypes.cast<dynamic>().firstWhere(
          (value) => '${value['id']}' == '$id',
          orElse: () => null,
        );
    return '${item?['doctype_name'] ?? id}';
  }

  String permissionName(dynamic id) {
    final item = permissions.cast<dynamic>().firstWhere(
          (value) => '${value['id']}' == '$id',
          orElse: () => null,
        );
    return '${item?['action_name'] ?? id}';
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Security & Access Control',
      subtitle: 'Manage roles, permissions, scopes and authorization rules',
      loading: loading,
      onRefresh: load,
      children: [
        if (errorMessage != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(errorMessage!)),
                ],
              ),
            ),
          ),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            Stat(
              title: 'Roles',
              value: '${roles.length}',
              icon: Icons.groups_2_outlined,
            ),
            Stat(
              title: 'DocTypes',
              value: '${doctypes.length}',
              icon: Icons.dataset_outlined,
            ),
            Stat(
              title: 'Permissions',
              value: '${permissions.length}',
              icon: Icons.lock_outline,
            ),
            Stat(
              title: 'Assignments',
              value: '${matrix.length}',
              icon: Icons.rule_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assign access',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add a permission for a role and define its access scope.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<int>(
                        initialValue: roles.any(
                          (item) => '${item['id']}' == '$selectedRoleId',
                        )
                            ? selectedRoleId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: roles.map((item) {
                          final id = int.tryParse('${item['id']}');
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text('${item['role_name']}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedRoleId = value);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<int>(
                        initialValue: doctypes.any(
                          (item) => '${item['id']}' == '$selectedDoctypeId',
                        )
                            ? selectedDoctypeId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'DocType',
                          border: OutlineInputBorder(),
                        ),
                        items: doctypes.map((item) {
                          final id = int.tryParse('${item['id']}');
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text('${item['doctype_name']}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedDoctypeId = value);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<int>(
                        initialValue: permissions.any(
                          (item) => '${item['id']}' == '$selectedPermissionId',
                        )
                            ? selectedPermissionId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Permission',
                          border: OutlineInputBorder(),
                        ),
                        items: permissions.map((item) {
                          final id = int.tryParse('${item['id']}');
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text('${item['action_name']}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedPermissionId = value);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedScope,
                        decoration: const InputDecoration(
                          labelText: 'Scope',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ALL',
                            child: Text('All'),
                          ),
                          DropdownMenuItem(
                            value: 'BRANCH',
                            child: Text('Branch'),
                          ),
                          DropdownMenuItem(
                            value: 'DEPARTMENT',
                            child: Text('Department'),
                          ),
                          DropdownMenuItem(
                            value: 'OWN',
                            child: Text('Own'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedScope = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: assignPermission,
                      icon: const Icon(Icons.add_moderator_outlined),
                      label: const Text('Assign Permission'),
                    ),
                    OutlinedButton.icon(
                      onPressed: checkPermission,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Check Access'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business action authorization',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Evaluate an action against the authenticated account and optional target record.',
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: actionController,
                        decoration: const InputDecoration(
                          labelText: 'Action',
                          hintText: 'mark_attendance',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: TextField(
                        controller: actionDoctypeController,
                        decoration: const InputDecoration(
                          labelText: 'DocType',
                          hintText: 'Attendance',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: actionRecordController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Record ID',
                          hintText: 'Optional',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: checkBusinessAction,
                      icon: const Icon(Icons.policy_outlined),
                      label: const Text('Evaluate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Access assignments',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${matrix.length} assignments',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (matrix.isEmpty)
                  const EmptyState(
                    message: 'No access assignments available.',
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('DocType')),
                        DataColumn(label: Text('Permission')),
                        DataColumn(label: Text('Scope')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: matrix.map((item) {
                        final row = Map<String, dynamic>.from(item);
                        return DataRow(
                          cells: [
                            DataCell(Text('${row['role_name'] ?? '-'}')),
                            DataCell(Text('${row['doctype_name'] ?? '-'}')),
                            DataCell(Text('${row['permission'] ?? '-'}')),
                            DataCell(Text('${row['scope'] ?? 'ALL'}')),
                            DataCell(
                              Badge(
                                text: row['is_active'] == 1
                                    ? 'ACTIVE'
                                    : 'INACTIVE',
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _SecurityInfoCard(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Roles',
              value: '${roles.length}',
              description: 'Application roles available for assignment.',
            ),
            _SecurityInfoCard(
              icon: Icons.dataset_outlined,
              title: 'DocTypes',
              value: '${doctypes.length}',
              description: 'Academic and administrative resources.',
            ),
            _SecurityInfoCard(
              icon: Icons.key_outlined,
              title: 'Permissions',
              value: '${permissions.length}',
              description: 'Actions that can be granted to roles.',
            ),
          ],
        ),
      ],
    );
  }
}

class _SecurityInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String description;

  const _SecurityInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PageFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onRefresh;
  final Widget? action;
  final List<Widget> children;

  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    this.loading = false,
    this.onRefresh,
    this.action,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(subtitle),
                ],
              ),
            ),
            if (onRefresh != null)
              IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
            if (action != null) ...[
              const SizedBox(width: 8),
              action!,
            ],
          ],
        ),
        const SizedBox(height: 24),
        if (loading) const LinearProgressIndicator(),
        ...children,
      ],
    );
  }
}

class Stat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const Stat(
      {super.key,
      required this.title,
      required this.value,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Badge extends StatelessWidget {
  final String text;

  const Badge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;

  const EmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: Text(message)),
    );
  }
}
