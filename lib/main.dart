import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io show File;
import 'package:animate_do/animate_do.dart';

void main() {
  runApp(QuizApp());
}

class QuizApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Organization Quiz App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF1565C0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Color(0xFFF3F7FF),
        cardTheme: CardThemeData(
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          shadowColor: Colors.blue.withOpacity(0.3),
        ),
        textTheme: TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D47A1),
            fontFamily: 'Roboto',
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1565C0),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Color(0xFF263238),
            fontFamily: 'Roboto',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1565C0),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: Colors.blue.withOpacity(0.4),
            textStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Models
class Question {
  final String question;
  final List<String> options;
  final int correctAnswer;

  Question({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correctAnswer': correctAnswer,
      };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        question: json['question'],
        options: List<String>.from(json['options']),
        correctAnswer: json['correctAnswer'],
      );
}

class Quiz {
  final String id;
  final String title;
  final List<Question> questions;
  final int timePerQuestion;
  final DateTime createdAt;
  bool isActive;

  Quiz({
    required this.id,
    required this.title,
    required this.questions,
    required this.timePerQuestion,
    required this.createdAt,
    this.isActive = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'questions': questions.map((q) => q.toJson()).toList(),
        'timePerQuestion': timePerQuestion,
        'createdAt': createdAt.toIso8601String(),
        'isActive': isActive,
      };

  factory Quiz.fromJson(Map<String, dynamic> json) => Quiz(
        id: json['id'],
        title: json['title'],
        questions: (json['questions'] as List).map((q) => Question.fromJson(q)).toList(),
        timePerQuestion: json['timePerQuestion'],
        createdAt: DateTime.parse(json['createdAt']),
        isActive: json['isActive'] ?? false,
      );
}

class ParticipantResult {
  final String participantName;
  final String institutionName;
  final String quizId;
  final int score;
  final int totalQuestions;
  final DateTime completedAt;
  final int totalTimeSpent;

  ParticipantResult({
    required this.participantName,
    required this.institutionName,
    required this.quizId,
    required this.score,
    required this.totalQuestions,
    required this.completedAt,
    required this.totalTimeSpent,
  });

  Map<String, dynamic> toJson() => {
        'participantName': participantName,
        'institutionName': institutionName,
        'quizId': quizId,
        'score': score,
        'totalQuestions': totalQuestions,
        'completedAt': completedAt.toIso8601String(),
        'totalTimeSpent': totalTimeSpent,
      };

  factory ParticipantResult.fromJson(Map<String, dynamic> json) => ParticipantResult(
        participantName: json['participantName'],
        institutionName: json['institutionName'] ?? '',
        quizId: json['quizId'],
        score: json['score'],
        totalQuestions: json['totalQuestions'],
        completedAt: DateTime.parse(json['completedAt']),
        totalTimeSpent: json['totalTimeSpent'],
      );
}

// Data Manager
class QuizDataManager {
  static final QuizDataManager _instance = QuizDataManager._internal();
  factory QuizDataManager() => _instance;
  QuizDataManager._internal();

  final List<Quiz> _quizzes = [];
  final List<ParticipantResult> _results = [];
  final String _baseUrl = 'https://vinjanakeralamquizz-backend-1.onrender.com/api';
  final String _adminApiKey = 'ADMIN123';
  final StreamController<List<ParticipantResult>> _resultsStreamController =
      StreamController<List<ParticipantResult>>.broadcast();

  List<Quiz> get quizzes => _quizzes;
  List<ParticipantResult> get results => _results;
  Stream<List<ParticipantResult>> get resultsStream => _resultsStreamController.stream;

  Future<void> loadQuizzes(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/quizzes/active'));
      if (response.statusCode == 200) {
        final List<dynamic> quizJson = jsonDecode(response.body);
        _quizzes.clear();
        _quizzes.addAll(quizJson.map((q) => Quiz.fromJson(q)).toList());
      } else {
        throw Exception('Failed to load quizzes: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error loading quizzes from server: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load quizzes from server. Using local data.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      final quizData = prefs.getString('quizzes');
      if (quizData != null) {
        final List<dynamic> quizJson = jsonDecode(quizData);
        _quizzes.clear();
        _quizzes.addAll(quizJson.map((q) => Quiz.fromJson(q)).toList());
      }
    }
  }

  Future<void> saveQuizzes(BuildContext context, Quiz quiz) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/quizzes'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _adminApiKey,
        },
        body: jsonEncode(quiz.toJson()),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to save quiz: ${response.statusCode} - ${response.body}');
      }
      _quizzes.add(quiz);
    } catch (e) {
      print('Error saving quiz to server: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save quiz to server: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    final quizJson = jsonEncode(_quizzes.map((q) => q.toJson()).toList());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quizzes', quizJson);
  }

  Future<void> updateQuizStatus(BuildContext context, String quizId, bool isActive) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/quizzes/$quizId/status'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _adminApiKey,
        },
        body: jsonEncode({'isActive': isActive}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update quiz status: ${response.statusCode} - ${response.body}');
      }
      final quiz = _quizzes.firstWhere((q) => q.id == quizId);
      quiz.isActive = isActive;
    } catch (e) {
      print('Error updating quiz status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update quiz status: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    final quizJson = jsonEncode(_quizzes.map((q) => q.toJson()).toList());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quizzes', quizJson);
  }

  Future<void> loadResults(BuildContext context, String quizId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/results/$quizId'));
      if (response.statusCode == 200) {
        final List<dynamic> resultJson = jsonDecode(response.body);
        _results.clear();
        _results.addAll(resultJson.map((r) => ParticipantResult.fromJson(r)).toList());
        _resultsStreamController.add(getQuizResults(quizId));
      } else {
        throw Exception('Failed to load results: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error loading results from server: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load results from server. Using local data.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      final prefs = await SharedPreferences.getInstance();
      final resultList = prefs.getStringList('results') ?? [];
      _results.clear();
      _results.addAll(
        resultList
            .map((r) => ParticipantResult.fromJson(jsonDecode(r)))
            .where((r) => r.quizId == quizId)
            .toList(),
      );
      _resultsStreamController.add(getQuizResults(quizId));
    }
  }

  Future<void> saveResult(ParticipantResult result) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/results'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(result.toJson()),
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to save result: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error saving result to server: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    final results = prefs.getStringList('results') ?? [];
    results.add(jsonEncode(result.toJson()));
    await prefs.setStringList('results', results);
  }

  void addQuiz(BuildContext context, Quiz quiz) {
    saveQuizzes(context, quiz);
  }

  void addResult(ParticipantResult result) {
    _results.add(result);
    saveResult(result);
    _resultsStreamController.add(getQuizResults(result.quizId));
  }

  List<Quiz> getActiveQuizzes() {
    return _quizzes.where((quiz) => quiz.isActive).toList();
  }

  List<ParticipantResult> getQuizResults(String quizId) {
    return _results.where((result) => result.quizId == quizId).toList()
      ..sort((a, b) {
        int scoreComparison = b.score.compareTo(a.score);
        if (scoreComparison != 0) return scoreComparison;
        return a.totalTimeSpent.compareTo(b.totalTimeSpent);
      });
  }

  void startLiveUpdates(BuildContext context, String quizId) {
    Timer.periodic(Duration(seconds: 3), (timer) {
      loadResults(context, quizId);
    });
  }

  void dispose() {
    _resultsStreamController.close();
  }
}

// Home Screen
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D47A1),
              Color(0xFF1565C0),
              Color(0xFF1976D2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeInUp(
              duration: Duration(milliseconds: 800),
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ZoomIn(
                      duration: Duration(milliseconds: 1000),
                      child: Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Image.network('https://vijnanakeralam.kerala.gov.in/kkem/images/vk_preloader.png',
                        height: 100,
                        width: 100,
                        fit: BoxFit.contain,),
                      ),
                    ),
                    SizedBox(height: 40),
                    FadeInUp(
                      delay: Duration(milliseconds: 200),
                      child: Text(
                        'VijnanaKeralamQuiz',
                        style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    SizedBox(height: 12),
                    FadeInUp(
                      delay: Duration(milliseconds: 400),
                      child: Text(
                        'Challenge your knowledge with interactive quizzes!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                          fontFamily: 'Roboto',
                          height: 1.4,
                        ),
                      ),
                    ),
                    SizedBox(height: 60),
                    _buildRoleButton(
                      context,
                      'Admin Dashboard',
                      Icons.admin_panel_settings_rounded,
                      Color(0xFF00BCD4),
                      () => _navigateToAdmin(context),
                      delay: 600,
                    ),
                    SizedBox(height: 24),
                    _buildRoleButton(
                      context,
                      'Join as Participant',
                      Icons.person_rounded,
                      Color(0xFF00E676),
                      () => _navigateToParticipant(context),
                      delay: 800,
                    ),
                    SizedBox(height: 24),
                    _buildRoleButton(
                      context,
                      'Live Leaderboard',
                      Icons.leaderboard_rounded,
                      Color(0xFFFFC107),
                      () => _navigateToLiveLeaderboard(context),
                      delay: 1000,
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

  Widget _buildRoleButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    {required int delay}) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Container(
        width: double.infinity,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 32),
          label: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  void _navigateToAdmin(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AdminPasscodeDialog(),
    );
  }

  void _navigateToParticipant(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ParticipantDetailsDialog(),
    );
  }

  void _navigateToLiveLeaderboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LiveLeaderboardScreen()),
    );
  }
}

// Admin Passcode Dialog
class AdminPasscodeDialog extends StatefulWidget {
  const AdminPasscodeDialog({super.key});

  @override
  _AdminPasscodeDialogState createState() => _AdminPasscodeDialogState();
}

class _AdminPasscodeDialogState extends State<AdminPasscodeDialog> {
  final _passcodeController = TextEditingController();
  final String _correctPasscode = "ADMIN123";
  bool _isObscured = true;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeIn(
              duration: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.security_rounded,
                  size: 48,
                  color: Color(0xFF1565C0),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Admin Access',
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your admin passcode to continue',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passcodeController,
              obscureText: _isObscured,
              decoration: InputDecoration(
                hintText: 'Enter passcode',
                prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF1565C0)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscured ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF1565C0),
                  ),
                  onPressed: () => setState(() => _isObscured = !_isObscured),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF1565C0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFF1565C0).withOpacity(0.05),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _verifyPasscode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Enter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _verifyPasscode() {
    if (_passcodeController.text == _correctPasscode) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdminDashboard()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid passcode! Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }
}

// Participant Details Dialog
class ParticipantDetailsDialog extends StatefulWidget {
  @override
  _ParticipantDetailsDialogState createState() => _ParticipantDetailsDialogState();
}

class _ParticipantDetailsDialogState extends State<ParticipantDetailsDialog> {
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeIn(
                duration: Duration(milliseconds: 500),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF00E676).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.person_add_rounded,
                    size: 48,
                    color: Color(0xFF00E676),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Join Quiz',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 8),
              Text(
                'Please provide your details to continue',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person_rounded, color: Color(0xFF1565C0)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Color(0xFF1565C0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Color(0xFF1565C0), width: 2),
                  ),
                  filled: true,
                  fillColor: Color(0xFF1565C0).withOpacity(0.05),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _institutionController,
                decoration: InputDecoration(
                  hintText: 'Enter your institution/organization',
                  prefixIcon: Icon(Icons.school_rounded, color: Color(0xFF1565C0)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Color(0xFF1565C0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Color(0xFF1565C0), width: 2),
                  ),
                  filled: true,
                  fillColor: Color(0xFF1565C0).withOpacity(0.05),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your institution';
                  }
                  return null;
                },
              ),
              SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _enterAsParticipant,
                      child: Text('Continue'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00E676),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enterAsParticipant() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ParticipantDashboard(
            participantName: _nameController.text.trim(),
            institutionName: _institutionController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    super.dispose();
  }
}

// Admin Dashboard
class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final QuizDataManager _dataManager = QuizDataManager();

  @override
  void initState() {
    super.initState();
    _dataManager.loadQuizzes(context).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: () {
              _dataManager.loadQuizzes(context).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF3F7FF),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInDown(
                duration: Duration(milliseconds: 600),
                child: Container(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _createNewQuiz,
                    icon: Icon(Icons.add_rounded, size: 28),
                    label: Text('Create New Quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00E676),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32),
              Text(
                'Quiz Management',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: _dataManager.quizzes.isEmpty
                    ? Center(
                        child: FadeIn(
                          duration: Duration(milliseconds: 800),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.quiz_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No quizzes created yet',
                                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 18,
                                    ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap "Create New Quiz" to get started',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _dataManager.quizzes.length,
                        itemBuilder: (context, index) {
                          final quiz = _dataManager.quizzes[index];
                          return FadeInUp(
                            duration: Duration(milliseconds: 600 + index * 100),
                            child: Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Color(0xFF1565C0),
                                  child: Icon(Icons.quiz, color: Colors.white),
                                ),
                                title: Text(
                                  quiz.title,
                                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                subtitle: Text(
                                  '${quiz.questions.length} questions • ${quiz.timePerQuestion}s per question',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: quiz.isActive,
                                      activeColor: Color(0xFF00E676),
                                      onChanged: (value) {
                                        _dataManager
                                            .updateQuizStatus(context, quiz.id, value)
                                            .then((_) => setState(() {}));
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.leaderboard, color: Color(0xFF1565C0)),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => LeaderboardScreen(quiz: quiz),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createNewQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateQuizScreen()),
    ).then((_) => _dataManager.loadQuizzes(context).then((_) => setState(() {})));
  }
}

// Question Input Dialog
class QuestionInputDialog extends StatefulWidget {
  final Function(List<Question>) onQuestionsAdded;

  QuestionInputDialog({required this.onQuestionsAdded});

  @override
  _QuestionInputDialogState createState() => _QuestionInputDialogState();
}

class _QuestionInputDialogState extends State<QuestionInputDialog> {
  final _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeIn(
              duration: Duration(milliseconds: 500),
              child: Text(
                'Add Questions',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Enter questions in the format (one per line):',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: 8),
            Text(
              'Question|Option1|Option2|Option3|Option4|CorrectAnswerIndex',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Or upload a text file with the same format',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _uploadFile,
              icon: Icon(Icons.upload_file),
              label: Text('Upload File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText:
                    'Example:\nWhat is 2+2?|3|4|5|6|2\nCapital of France?|London|Paris|Berlin|Madrid|2',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Color(0xFF1565C0).withOpacity(0.05),
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _processQuestions,
                    child: Text('Add Questions'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result != null) {
        String content;
        if (kIsWeb) {
          content = String.fromCharCodes(result.files.single.bytes!);
        } else {
          content = await io.File(result.files.single.path!).readAsString();
        }
        setState(() {
          _textController.text = content;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading file: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _processQuestions() {
    try {
      List<Question> questions = [];
      List<String> lines = _textController.text.split('\n');

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        List<String> parts = line.split('|');
        if (parts.length != 6) {
          throw Exception('Invalid format in line: $line');
        }
        String questionText = parts[0].trim();
        List<String> options = [
          parts[1].trim(),
          parts[2].trim(),
          parts[3].trim(),
          parts[4].trim(),
        ];
        int correctAnswer = int.parse(parts[5].trim()) - 1;

        if (correctAnswer < 0 || correctAnswer >= 4) {
          throw Exception('Invalid correct answer index in line: $line');
        }

        questions.add(Question(
          question: questionText,
          options: options,
          correctAnswer: correctAnswer,
        ));
      }

      if (questions.isEmpty) {
        throw Exception('No valid questions provided');
      }

      widget.onQuestionsAdded(questions);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully added ${questions.length} questions!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

// Create Quiz Screen
class CreateQuizScreen extends StatefulWidget {
  @override
  _CreateQuizScreenState createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _titleController = TextEditingController();
  final _timeController = TextEditingController(text: '30');
  List<Question> _questions = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Quiz'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F7FF), Colors.white],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeIn(
                duration: Duration(milliseconds: 500),
                child: TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Quiz Title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Color(0xFF1565C0).withOpacity(0.05),
                  ),
                ),
              ),
              SizedBox(height: 16),
              FadeIn(
                duration: Duration(milliseconds: 600),
                child: TextField(
                  controller: _timeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Time per question (seconds)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Color(0xFF1565C0).withOpacity(0.05),
                  ),
                ),
              ),
              SizedBox(height: 24),
              FadeIn(
                duration: Duration(milliseconds: 700),
                child: ElevatedButton.icon(
                  onPressed: _showQuestionInputDialog,
                  icon: Icon(Icons.add_rounded),
                  label: Text('Add Questions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00E676),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              SizedBox(height: 16),
              FadeIn(
                duration: Duration(milliseconds: 800),
                child: ElevatedButton.icon(
                  onPressed: _showSampleFormat,
                  icon: Icon(Icons.info_rounded),
                  label: Text('View Sample Format'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              SizedBox(height: 24),
              if (_questions.isNotEmpty)
                FadeIn(
                  duration: Duration(milliseconds: 900),
                  child: Text(
                    'Loaded ${_questions.length} questions',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final question = _questions[index];
                    return FadeInUp(
                      duration: Duration(milliseconds: 600 + index * 100),
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Q${index + 1}: ${question.question}',
                                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              SizedBox(height: 8),
                              ...question.options.asMap().entries.map((entry) {
                                int idx = entry.key;
                                String option = entry.value;
                                return Text(
                                  '${String.fromCharCode(65 + idx)}. $option',
                                  style: TextStyle(
                                    color: idx == question.correctAnswer
                                        ? Colors.green
                                        : Colors.black87,
                                    fontWeight: idx == question.correctAnswer
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 24),
              FadeIn(
                duration: Duration(milliseconds: 1000),
                child: ElevatedButton(
                  onPressed: _canCreateQuiz() ? _createQuiz : null,
                  child: Text('Create Quiz'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canCreateQuiz() {
    return _titleController.text.trim().isNotEmpty &&
        _timeController.text.trim().isNotEmpty &&
        _questions.isNotEmpty;
  }

  void _showQuestionInputDialog() {
    showDialog(
      context: context,
      builder: (context) => QuestionInputDialog(
        onQuestionsAdded: (questions) {
          setState(() {
            _questions = questions;
          });
        },
      ),
    );
  }

  void _showSampleFormat() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question Format',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 16),
              Text(
                'Format each question as:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              SizedBox(height: 8),
              Text(
                'Question|Option1|Option2|Option3|Option4|CorrectAnswerIndex',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              Text(
                'Example:',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              SizedBox(height: 8),
              Text(
                'What is 2+2?|3|4|5|6|2\nCapital of France?|London|Paris|Berlin|Madrid|2',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              Text(
                'Note: Correct answer index starts from 1',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Got it'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createQuiz() {
    final quiz = Quiz(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      questions: _questions,
      timePerQuestion: int.parse(_timeController.text),
      createdAt: DateTime.now(),
      isActive: true,
    );

    QuizDataManager().addQuiz(context, quiz);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quiz created successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    super.dispose();
  }
}

// Participant Dashboard
class ParticipantDashboard extends StatefulWidget {
  final String participantName;
  final String institutionName;

  ParticipantDashboard({
    required this.participantName,
    required this.institutionName,
  });

  @override
  _ParticipantDashboardState createState() => _ParticipantDashboardState();
}

class _ParticipantDashboardState extends State<ParticipantDashboard> {
  final QuizDataManager _dataManager = QuizDataManager();

  @override
  void initState() {
    super.initState();
    _dataManager.loadQuizzes(context).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final activeQuizzes = _dataManager.getActiveQuizzes();

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.participantName}'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: () {
              _dataManager.loadQuizzes(context).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F7FF), Colors.white],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Quizzes',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: activeQuizzes.isEmpty
                    ? Center(
                        child: FadeIn(
                          duration: Duration(milliseconds: 800),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.quiz_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No active quizzes available',
                                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 18,
                                    ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Please wait for an admin to start a quiz',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: activeQuizzes.length,
                        itemBuilder: (context, index) {
                          final quiz = activeQuizzes[index];
                          return FadeInUp(
                            duration: Duration(milliseconds: 600 + index * 100),
                            child: Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Color(0xFF1565C0),
                                  child: Icon(Icons.quiz, color: Colors.white),
                                ),
                                title: Text(
                                  quiz.title,
                                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                subtitle: Text(
                                  '${quiz.questions.length} questions • ${quiz.timePerQuestion}s per question',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _joinQuiz(quiz),
                                  child: Text('Join'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF00E676),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _joinQuiz(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          quiz: quiz,
          participantName: widget.participantName,
          institutionName: widget.institutionName,
        ),
      ),
    );
  }
}

// Quiz Screen
class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  final String participantName;
  final String institutionName;

  QuizScreen({
    required this.quiz,
    required this.participantName,
    required this.institutionName,
  });

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int _selectedAnswer = -1;
  int _score = 0;
  Timer? _timer;
  int _timeLeft = 0;
  DateTime _quizStartTime = DateTime.now();
  List<int> _answers = [];

  @override
  void initState() {
    super.initState();
    _quizStartTime = DateTime.now();
    _answers = List.filled(widget.quiz.questions.length, -1);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timeLeft = widget.quiz.timePerQuestion;
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _nextQuestion();
        }
      });
    });
  }

  void _nextQuestion() {
    _timer?.cancel();

    _answers[_currentQuestionIndex] = _selectedAnswer;

    if (_selectedAnswer != -1 &&
        _selectedAnswer == widget.quiz.questions[_currentQuestionIndex].correctAnswer) {
      _score++;
    }

    if (_currentQuestionIndex < widget.quiz.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = -1;
      });
      _startTimer();
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    final totalTime = DateTime.now().difference(_quizStartTime).inSeconds;

    final result = ParticipantResult(
      participantName: widget.participantName,
      institutionName: widget.institutionName,
      quizId: widget.quiz.id,
      score: _score,
      totalQuestions: widget.quiz.questions.length,
      completedAt: DateTime.now(),
      totalTimeSpent: totalTime,
    );

    QuizDataManager().addResult(result);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultScreen(
          result: result,
          quiz: widget.quiz,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.quiz.questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F7FF), Colors.white],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeIn(
                duration: Duration(milliseconds: 500),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1} of ${widget.quiz.questions.length}',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _timeLeft <= 5 ? Colors.red : Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_timeLeft s',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / widget.quiz.questions.length,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
              ),
              SizedBox(height: 24),
              FadeIn(
                duration: Duration(milliseconds: 600),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      question.question,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: question.options.length,
                  itemBuilder: (context, index) {
                    return FadeInUp(
                      duration: Duration(milliseconds: 600 + index * 100),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: RadioListTile<int>(
                          value: index,
                          groupValue: _selectedAnswer,
                          onChanged: (value) {
                            setState(() {
                              _selectedAnswer = value!;
                            });
                          },
                          title: Text(
                            '${String.fromCharCode(65 + index)}. ${question.options[index]}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          activeColor: Color(0xFF1565C0),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 24),
              FadeIn(
                duration: Duration(milliseconds: 700),
                child: ElevatedButton(
                  onPressed: _selectedAnswer != -1 ? _nextQuestion : null,
                  child: Text(
                    _currentQuestionIndex == widget.quiz.questions.length - 1
                        ? 'Finish Quiz'
                        : 'Next Question',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Quiz Result Screen
class QuizResultScreen extends StatelessWidget {
  final ParticipantResult result;
  final Quiz quiz;

  const QuizResultScreen({super.key, required this.result, required this.quiz});

  @override
  Widget build(BuildContext context) {
    final percentage = (result.score / result.totalQuestions * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F7FF), Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeIn(
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: percentage >= 70 ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                  ),
                  child: Icon(
                    percentage >= 70 ? Icons.check : Icons.close,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeIn(
                duration: const Duration(milliseconds: 600),
                child: Text(
                  percentage >= 70 ? 'Congratulations!' : 'Better Luck Next Time!',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              const SizedBox(height: 24),
              FadeIn(
                duration: const Duration(milliseconds: 700),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildResultRow(context, 'Participant', result.participantName),
                        _buildResultRow(context, 'Institution', result.institutionName),
                        _buildResultRow(context, 'Quiz', quiz.title),
                        _buildResultRow(context, 'Score', '${result.score}/${result.totalQuestions}'),
                        _buildResultRow(context, 'Percentage', '$percentage%'),
                        _buildResultRow(context, 'Time Taken', _formatTime(result.totalTimeSpent)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FadeIn(
                      duration: const Duration(milliseconds: 800),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LeaderboardScreen(quiz: quiz),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                        ),
                        child: const Text('View Leaderboard'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FadeIn(
                      duration: const Duration(milliseconds: 900),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => HomeScreen()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                        ),
                        child: const Text('Back to Home'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

// Leaderboard Screen
class LeaderboardScreen extends StatefulWidget {
  final Quiz quiz;

  LeaderboardScreen({required this.quiz});

  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final QuizDataManager _dataManager = QuizDataManager();

  @override
  void initState() {
    super.initState();
    _dataManager.loadResults(context, widget.quiz.id);
    _dataManager.startLiveUpdates(context, widget.quiz.id);
  }

  @override
  void dispose() {
    _dataManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.quiz.title} Leaderboard'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F7FF), Colors.white],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: StreamBuilder<List<ParticipantResult>>(
            stream: _dataManager.resultsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final results = snapshot.data ?? _dataManager.getQuizResults(widget.quiz.id);

              if (results.isEmpty) {
                return Center(
                  child: FadeIn(
                    duration: Duration(milliseconds: 800),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.leaderboard_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No participants yet',
                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                color: Colors.grey[600],
                                fontSize: 18,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeIn(
                    duration: Duration(milliseconds: 500),
                    child: Text(
                      widget.quiz.title,
                      style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  SizedBox(height: 8),
                  FadeIn(
                    duration: Duration(milliseconds: 600),
                    child: Text(
                      '${results.length} participants',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final result = results[index];
                        final percentage = (result.score / result.totalQuestions * 100).round();
                        return FadeInUp(
                          duration: Duration(milliseconds: 600 + index * 100),
                          child: Card(
                            elevation: index < 3 ? 12 : 8,
                            color: index < 3
                                ? _getTopThreeColor(index)
                                : Colors.white.withOpacity(0.9),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: index < 3 ? Colors.white : Color(0xFF1565C0),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: index < 3 ? _getTopThreeColor(index) : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                result.participantName,
                                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: index < 3 ? Colors.white : null,
                                    ),
                              ),
                              subtitle: Text(
                                '${result.institutionName}\n${_formatDateTime(result.completedAt)}',
                                style: TextStyle(
                                  color: index < 3 ? Colors.white70 : Colors.grey[600],
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${result.score}/${result.totalQuestions}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: index < 3 ? Colors.white : null,
                                    ),
                                  ),
                                  Text(
                                    '$percentage% • ${_formatTime(result.totalTimeSpent)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: index < 3 ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getTopThreeColor(int index) {
    switch (index) {
      case 0:
        return Color(0xFFFFD700); // Gold
      case 1:
        return Color(0xFFC0C0C0); // Silver
      case 2:
        return Color(0xFFCD7F32); // Bronze
      default:
        return Color(0xFF1565C0);
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// Live Leaderboard Screen
class LiveLeaderboardScreen extends StatefulWidget {
  @override
  _LiveLeaderboardScreenState createState() => _LiveLeaderboardScreenState();
}

class _LiveLeaderboardScreenState extends State<LiveLeaderboardScreen> {
  final QuizDataManager _dataManager = QuizDataManager();

  @override
  void initState() {
    super.initState();
    _dataManager.loadQuizzes(context).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final activeQuizzes = _dataManager.getActiveQuizzes();

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Leaderboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: () {
              _dataManager.loadQuizzes(context).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F7FF), Colors.white],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeIn(
                duration: Duration(milliseconds: 500),
                child: Text(
                  'Active Quizzes',
                  style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: activeQuizzes.isEmpty
                    ? Center(
                        child: FadeIn(
                          duration: Duration(milliseconds: 800),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.quiz_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No active quizzes available',
                                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 18,
                                    ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Please wait for an admin to start a quiz',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: activeQuizzes.length,
                        itemBuilder: (context, index) {
                          final quiz = activeQuizzes[index];
                          return FadeInUp(
                            duration: Duration(milliseconds: 600 + index * 100),
                            child: Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Color(0xFF1565C0),
                                  child: Icon(Icons.quiz, color: Colors.white),
                                ),
                                title: Text(
                                  quiz.title,
                                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                subtitle: Text(
                                  '${quiz.questions.length} questions • ${quiz.timePerQuestion}s per question',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _viewLeaderboard(quiz),
                                  child: Text('View Live Leaderboard'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFFFFC107),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewLeaderboard(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaderboardScreen(quiz: quiz),
      ),
    );
  }
}