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
        primaryColor: Color(0xFF1A237E),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.indigo,
          accentColor: Color(0xFFFF6F00),
        ).copyWith(
          secondary: Color(0xFFFF6F00),
        ),
        scaffoldBackgroundColor: Color(0xFFF5F7FA),
        cardTheme: CardThemeData( // Changed to CardThemeData
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: Colors.black26,
        ),
        textTheme: TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
            fontFamily: 'Roboto',
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A237E),
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontFamily: 'Roboto',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1A237E),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            textStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Models (unchanged)
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
  final String quizId;
  final int score;
  final int totalQuestions;
  final DateTime completedAt;
  final int totalTimeSpent;

  ParticipantResult({
    required this.participantName,
    required this.quizId,
    required this.score,
    required this.totalQuestions,
    required this.completedAt,
    required this.totalTimeSpent,
  });

  Map<String, dynamic> toJson() => {
        'participantName': participantName,
        'quizId': quizId,
        'score': score,
        'totalQuestions': totalQuestions,
        'completedAt': completedAt.toIso8601String(),
        'totalTimeSpent': totalTimeSpent,
      };

  factory ParticipantResult.fromJson(Map<String, dynamic> json) => ParticipantResult(
        participantName: json['participantName'],
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
  final String _baseUrl = 'https://your-backend-service.onrender.com/api'; // Update with Render URL
  final String _adminApiKey = 'ADMIN123';

  List<Quiz> get quizzes => _quizzes;
  List<ParticipantResult> get results => _results;

  Future<void> loadQuizzes() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/quizzes/active'));
      if (response.statusCode == 200) {
        final List<dynamic> quizJson = jsonDecode(response.body);
        _quizzes.clear();
        _quizzes.addAll(quizJson.map((q) => Quiz.fromJson(q)).toList());
      } else {
        throw Exception('Failed to load quizzes: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading quizzes from server: $e');
      final prefs = await SharedPreferences.getInstance();
      final quizData = prefs.getString('quizzes');
      if (quizData != null) {
        final List<dynamic> quizJson = jsonDecode(quizData);
        _quizzes.clear();
        _quizzes.addAll(quizJson.map((q) => Quiz.fromJson(q)).toList());
      }
    }
  }

  Future<void> saveQuizzes(Quiz quiz) async {
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
        throw Exception('Failed to save quiz: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving quiz to server: $e');
    }
    _quizzes.add(quiz);
    final quizJson = jsonEncode(_quizzes.map((q) => q.toJson()).toList());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quizzes', quizJson);
  }

  Future<void> updateQuizStatus(String quizId, bool isActive) async {
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
        throw Exception('Failed to update quiz status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating quiz status: $e');
    }
    final quiz = _quizzes.firstWhere((q) => q.id == quizId);
    quiz.isActive = isActive;
    final quizJson = jsonEncode(_quizzes.map((q) => q.toJson()).toList());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('quizzes', quizJson);
  }

  Future<void> loadResults(String quizId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/results/$quizId'));
      if (response.statusCode == 200) {
        final List<dynamic> resultJson = jsonDecode(response.body);
        _results.clear();
        _results.addAll(resultJson.map((r) => ParticipantResult.fromJson(r)).toList());
      } else {
        throw Exception('Failed to load results: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading results from server: $e');
      final prefs = await SharedPreferences.getInstance();
      final resultList = prefs.getStringList('results') ?? [];
      _results.clear();
      _results.addAll(
        resultList
            .map((r) => ParticipantResult.fromJson(jsonDecode(r)))
            .where((r) => r.quizId == quizId)
            .toList(),
      );
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
        throw Exception('Failed to save result: ${response.statusCode}');
      }
    } catch (e) {
      print('Error saving result to server: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    final results = prefs.getStringList('results') ?? [];
    results.add(jsonEncode(result.toJson()));
    await prefs.setStringList('results', results);
  }

  void addQuiz(Quiz quiz) {
    saveQuizzes(quiz);
  }

  void addResult(ParticipantResult result) {
    _results.add(result);
    saveResult(result);
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
}

// Home Screen
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeInUp(
              duration: Duration(milliseconds: 800),
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.quiz,
                      size: 100,
                      color: Colors.white,
                    ),
                    SizedBox(height: 30),
                    Text(
                      'Quiz Master',
                      style: Theme.of(context).textTheme.headlineLarge!.copyWith(
                            color: Colors.white,
                            fontSize: 32,
                          ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Test your knowledge or create quizzes!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    SizedBox(height: 50),
                    _buildRoleButton(
                      context,
                      'Admin',
                      Icons.admin_panel_settings,
                      Color(0xFFFF6F00),
                      () => _navigateToAdmin(context),
                    ),
                    SizedBox(height: 20),
                    _buildRoleButton(
                      context,
                      'Participant',
                      Icons.person,
                      Color(0xFF00C853),
                      () => _navigateToParticipant(context),
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
  ) {
    return ZoomIn(
      duration: Duration(milliseconds: 1000),
      child: Container(
        width: double.infinity,
        height: 60,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 28),
          label: Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withOpacity(0.9),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 5,
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
      builder: (context) => ParticipantNameDialog(),
    );
  }
}

// Admin Passcode Dialog
class AdminPasscodeDialog extends StatefulWidget {
  @override
  _AdminPasscodeDialogState createState() => _AdminPasscodeDialogState();
}

class _AdminPasscodeDialogState extends State<AdminPasscodeDialog> {
  final _passcodeController = TextEditingController();
  final String _correctPasscode = "ADMIN123";

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white.withOpacity(0.95),
      title: Text('Admin Access', style: Theme.of(context).textTheme.headlineMedium),
      content: FadeIn(
        duration: Duration(milliseconds: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter admin passcode:', style: Theme.of(context).textTheme.bodyLarge),
            SizedBox(height: 10),
            TextField(
              controller: _passcodeController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Passcode',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: _verifyPasscode,
          child: Text('Enter'),
        ),
      ],
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
          content: Text('Invalid passcode!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Participant Name Dialog
class ParticipantNameDialog extends StatefulWidget {
  @override
  _ParticipantNameDialogState createState() => _ParticipantNameDialogState();
}

class _ParticipantNameDialogState extends State<ParticipantNameDialog> {
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white.withOpacity(0.95),
      title: Text('Participant Details', style: Theme.of(context).textTheme.headlineMedium),
      content: FadeIn(
        duration: Duration(milliseconds: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your name:', style: Theme.of(context).textTheme.bodyLarge),
            SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Your Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: _enterAsParticipant,
          child: Text('Continue'),
        ),
      ],
    );
  }

  void _enterAsParticipant() {
    if (_nameController.text.trim().isNotEmpty) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ParticipantDashboard(
            participantName: _nameController.text.trim(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter your name!')),
      );
    }
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
    _dataManager.loadQuizzes().then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        backgroundColor: Color(0xFFFF6F00),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              duration: Duration(milliseconds: 600),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _createNewQuiz,
                      icon: Icon(Icons.add),
                      label: Text('Create New Quiz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00C853),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Existing Quizzes:',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 10),
            Expanded(
              child: _dataManager.quizzes.isEmpty
                  ? Center(
                      child: FadeIn(
                        duration: Duration(milliseconds: 800),
                        child: Text(
                          'No quizzes created yet.\nTap "Create New Quiz" to get started!',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                color: Colors.grey[600],
                              ),
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
                            color: Colors.white.withOpacity(0.9),
                            child: ListTile(
                              title: Text(quiz.title, style: Theme.of(context).textTheme.bodyLarge),
                              subtitle: Text(
                                '${quiz.questions.length} questions • ${quiz.timePerQuestion}s per question',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: quiz.isActive,
                                    activeColor: Color(0xFF00C853),
                                    onChanged: (value) {
                                      setState(() {
                                        _dataManager.updateQuizStatus(quiz.id, value);
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.leaderboard, color: Color(0xFF1A237E)),
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
    );
  }

  void _createNewQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateQuizScreen()),
    ).then((_) => setState(() {}));
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white.withOpacity(0.95),
      title: Text('Add Questions', style: Theme.of(context).textTheme.headlineMedium),
      content: Container(
        width: double.maxFinite,
        height: 400,
        child: FadeIn(
          duration: Duration(milliseconds: 500),
          child: Column(
            children: [
              Text(
                'Enter questions in this format (one per line):',
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
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
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploadFile,
                      icon: Icon(Icons.upload_file),
                      label: Text('Upload File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    hintText: 'Example:\nWhat is 2+2?|3|4|5|6|2\nCapital of France?|London|Paris|Berlin|Madrid|2',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: _processQuestions,
          child: Text('Add Questions'),
        ),
      ],
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
        ),
      );
    }
  }

  void _processQuestions() {
    try {
      List<Question> questions = [];
      List<String> lines = _textController.text.split('\n');

      for (int i = 0; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isEmpty) continue;

        List<String> parts = line.split('|');
        if (parts.length >= 6) {
          String questionText = parts[0].trim();
          List<String> options = [
            parts[1].trim(),
            parts[2].trim(),
            parts[3].trim(),
            parts[4].trim(),
          ];
          int correctAnswer = int.parse(parts[5].trim()) - 1;

          if (correctAnswer >= 0 && correctAnswer < 4) {
            questions.add(Question(
              question: questionText,
              options: options,
              correctAnswer: correctAnswer,
            ));
          }
        }
      }

      if (questions.isEmpty) {
        throw Exception('No valid questions found');
      }

      widget.onQuestionsAdded(questions);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e\n\nPlease check the format.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
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
        backgroundColor: Color(0xFF00C853),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FadeIn(
                    duration: Duration(milliseconds: 700),
                    child: ElevatedButton.icon(
                      onPressed: _showQuestionInputDialog,
                      icon: Icon(Icons.add),
                      label: Text('Add Questions'),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FadeIn(
                    duration: Duration(milliseconds: 800),
                    child: ElevatedButton.icon(
                      onPressed: _showSampleFormat,
                      icon: Icon(Icons.info),
                      label: Text('View Sample Format'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            if (_questions.isNotEmpty) ...[
              FadeIn(
                duration: Duration(milliseconds: 900),
                child: Text(
                  'Loaded ${_questions.length} questions',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final question = _questions[index];
                    return FadeInUp(
                      duration: Duration(milliseconds: 600 + index * 100),
                      child: Card(
                        color: Colors.white.withOpacity(0.9),
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Q${index + 1}: ${question.question}',
                                style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              ...question.options.asMap().entries.map((entry) {
                                int optionIndex = entry.key;
                                String option = entry.value;
                                bool isCorrect = optionIndex == question.correctAnswer;
                                return Padding(
                                  padding: EdgeInsets.only(left: 16, top: 4),
                                  child: Text(
                                    '${String.fromCharCode(65 + optionIndex)}. $option',
                                    style: TextStyle(
                                      color: isCorrect ? Colors.green : Colors.black,
                                      fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FadeIn(
                    duration: Duration(milliseconds: 1000),
                    child: ElevatedButton(
                      onPressed: _canCreateQuiz() ? _createQuiz : null,
                      child: Text('Create Quiz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully added ${questions.length} questions!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showSampleFormat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white.withOpacity(0.95),
        title: Text('Question Format', style: Theme.of(context).textTheme.headlineMedium),
        content: SingleChildScrollView(
          child: FadeIn(
            duration: Duration(milliseconds: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Format each question as:',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('Question|Option1|Option2|Option3|Option4|CorrectAnswerIndex'),
                SizedBox(height: 16),
                Text(
                  'Examples:',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('What is 2+2?|3|4|5|6|2'),
                Text('Capital of France?|London|Paris|Berlin|Madrid|2'),
                SizedBox(height: 16),
                Text(
                  'Note: Correct answer index starts from 1',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: TextStyle(color: Colors.grey[600])),
          ),
        ],
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
    );

    QuizDataManager().addQuiz(quiz);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quiz created successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }
}

// Participant Dashboard
class ParticipantDashboard extends StatefulWidget {
  final String participantName;

  ParticipantDashboard({required this.participantName});

  @override
  _ParticipantDashboardState createState() => _ParticipantDashboardState();
}

class _ParticipantDashboardState extends State<ParticipantDashboard> {
  final QuizDataManager _dataManager = QuizDataManager();

  @override
  void initState() {
    super.initState();
    _dataManager.loadQuizzes().then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final activeQuizzes = _dataManager.getActiveQuizzes();

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.participantName}'),
        backgroundColor: Color(0xFF00C853),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Quizzes:',
              style: Theme.of(context).textTheme.headlineMedium,
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
                                  ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Please wait for an admin to start a quiz',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
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
                            color: Colors.white.withOpacity(0.9),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Color(0xFF1A237E),
                                child: Icon(Icons.quiz, color: Colors.white),
                              ),
                              title: Text(
                                quiz.title,
                                style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${quiz.questions.length} questions • ${quiz.timePerQuestion}s per question',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => _joinQuiz(quiz),
                                child: Text('Join'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF00C853),
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
    );
  }

  void _joinQuiz(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          quiz: quiz,
          participantName: widget.participantName,
        ),
      ),
    );
  }
}

// Quiz Screen
class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  final String participantName;

  QuizScreen({required this.quiz, required this.participantName});

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
        backgroundColor: Color(0xFF1A237E),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
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
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _timeLeft <= 5 ? Colors.red : Color(0xFFFF6F00),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_timeLeft}s',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / widget.quiz.questions.length,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
            ),
            SizedBox(height: 32),
            FadeIn(
              duration: Duration(milliseconds: 600),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF1A237E).withOpacity(0.2)),
                ),
                child: Text(
                  question.question,
                  style: Theme.of(context).textTheme.headlineMedium,
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
                      padding: EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedAnswer = index;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _selectedAnswer == index
                                ? Color(0xFF1A237E).withOpacity(0.1)
                                : Colors.white.withOpacity(0.9),
                            border: Border.all(
                              color: _selectedAnswer == index
                                  ? Color(0xFF1A237E)
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _selectedAnswer == index
                                      ? Color(0xFF1A237E)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: _selectedAnswer == index
                                        ? Color(0xFF1A237E)
                                        : Colors.grey,
                                  ),
                                ),
                                child: _selectedAnswer == index
                                    ? Icon(Icons.check, size: 16, color: Colors.white)
                                    : null,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${String.fromCharCode(65 + index)}. ${question.options[index]}',
                                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                        fontWeight: _selectedAnswer == index
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            FadeIn(
              duration: Duration(milliseconds: 700),
              child: Container(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedAnswer != -1 ? _nextQuestion : null,
                  child: Text(
                    _currentQuestionIndex == widget.quiz.questions.length - 1
                        ? 'Finish Quiz'
                        : 'Next Question',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Quiz Result Screen
class QuizResultScreen extends StatelessWidget {
  final ParticipantResult result;
  final Quiz quiz;

  QuizResultScreen({required this.result, required this.quiz});
  
  BuildContext? get context => null;

  @override
  Widget build(BuildContext context) {
    final percentage = (result.score / result.totalQuestions * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz Complete'),
        backgroundColor: Color(0xFF00C853),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeIn(
                duration: Duration(milliseconds: 500),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: percentage >= 70 ? Color(0xFF00C853) : Color(0xFFFF6F00),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    percentage >= 70 ? Icons.check : Icons.info,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 24),
              FadeIn(
                duration: Duration(milliseconds: 600),
                child: Text(
                  'Quiz Completed!',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              SizedBox(height: 32),
              FadeIn(
                duration: Duration(milliseconds: 700),
                child: Card(
                  color: Colors.white.withOpacity(0.9),
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        _buildResultRow('Your Score', '${result.score}/${result.totalQuestions}'),
                        _buildResultRow('Percentage', '$percentage%'),
                        _buildResultRow('Time Taken', '${_formatTime(result.totalTimeSpent)}'),
                        _buildResultRow('Quiz', quiz.title),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: FadeIn(
                      duration: Duration(milliseconds: 800),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LeaderboardScreen(quiz: quiz),
                            ),
                          );
                        },
                        child: Text('View Leaderboard'),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: FadeIn(
                      duration: Duration(milliseconds: 900),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        child: Text('Back to Home'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
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

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context!).textTheme.bodyLarge!.copyWith(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: Theme.of(context!).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
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
    _dataManager.loadResults(widget.quiz.id).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final results = _dataManager.getQuizResults(widget.quiz.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('Leaderboard'),
        backgroundColor: Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeIn(
              duration: Duration(milliseconds: 500),
              child: Text(
                widget.quiz.title,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            SizedBox(height: 8),
            FadeIn(
              duration: Duration(milliseconds: 600),
              child: Text(
                '${results.length} participants',
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Colors.grey[600]),
              ),
            ),
            SizedBox(height: 24),
            Expanded(
              child: results.isEmpty
                  ? Center(
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
                                  ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final result = results[index];
                        final percentage = (result.score / result.totalQuestions * 100).round();

                        return FadeInUp(
                          duration: Duration(milliseconds: 600 + index * 100),
                          child: Card(
                            elevation: index < 3 ? 8 : 2,
                            color: index < 3 ? _getTopThreeColor(index) : Colors.white.withOpacity(0.9),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: index < 3 ? Colors.white : Color(0xFF1A237E),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: index < 3 ? _getTopThreeColor(index) : Colors.white,
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
                                'Completed: ${_formatDateTime(result.completedAt)}',
                                style: TextStyle(
                                  color: index < 3 ? Colors.white70 : Colors.grey[600],
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
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
        ),
      ),
    );
  }

  Color _getTopThreeColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber[600]!; // Gold
      case 1:
        return Colors.grey[600]!; // Silver
      case 2:
        return Colors.brown[400]!; // Bronze
      default:
        return Color(0xFF1A237E);
    }
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}