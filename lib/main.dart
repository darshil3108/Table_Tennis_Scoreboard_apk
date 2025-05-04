import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

void main() => runApp(ScoreboardApp());

class ScoreboardApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Table Tennis Scoreboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ScoreboardPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ScoreboardPage extends StatefulWidget {
  @override
  _ScoreboardPageState createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  int numSets = 3;
  int pointsPerSet = 11;
  int currentSet = 1;
  int scoreA = 0, scoreB = 0;
  int setsWonA = 0, setsWonB = 0;
  bool gameActive = false;
  String info = '';
  String lastHeard = '';

  // Speech recognition
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _speechInitialized = false;

  // For debugging
  List<String> recognitionHistory = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();

    // Configure TTS
    _flutterTts.setVolume(1.0);
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setPitch(1.0);
  }

  // Initialize speech recognition
  Future<bool> _initSpeech() async {
    if (_speechInitialized) return true;

    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'done' && _isListening) {
          // Immediately restart listening when done
          Future.delayed(Duration(milliseconds: 300), () {
            if (_isListening && gameActive) {
              _startListeningSession();
            }
          });
        }
      },
      onError: (error) {
        print('Speech error: $error');
        // Restart on error after a short delay
        if (_isListening && gameActive) {
          Future.delayed(Duration(milliseconds: 500), () {
            if (_isListening && gameActive) {
              _startListeningSession();
            }
          });
        }
      },
    );

    _speechInitialized = available;
    return available;
  }

  // Start a single listening session
  void _startListeningSession() {
    if (!_speech.isAvailable) return;

    try {
      _speech.listen(
        onResult: (result) {
          String words = result.recognizedWords.toLowerCase();

          if (words.isNotEmpty) {
            setState(() {
              lastHeard = words;

              // Add to history for debugging
              if (recognitionHistory.length >= 5) {
                recognitionHistory.removeAt(0);
              }
              recognitionHistory.add(words);
            });

            // Process the command
            _processVoiceInput(words);
          }
        },
        listenFor: Duration(seconds: 5),  // Short listening period
        pauseFor: Duration(seconds: 2),
        partialResults: true,
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: false,
      );
    } catch (e) {
      print("Error starting listening session: $e");
      // Try to restart after error
      Future.delayed(Duration(milliseconds: 500), () {
        if (_isListening && gameActive) {
          _startListeningSession();
        }
      });
    }
  }

  // Start continuous listening
  void startListening() async {
    if (_isListening) return;

    bool available = await _initSpeech();
    if (!available) {
      setState(() {
        info = "Speech recognition not available";
      });
      return;
    }

    setState(() {
      _isListening = true;
      info = "Listening...";
    });

    _startListeningSession();
  }

  // Stop listening
  void stopListening() {
    if (!_isListening) return;

    _speech.stop();
    setState(() {
      _isListening = false;
      info = "Voice recognition stopped";
    });
  }

  // Process voice input with very lenient matching
  void _processVoiceInput(String input) {
    if (!gameActive) return;

    print("Processing voice input: '$input'");

    // Super lenient matching - check for any occurrence of these letters/sounds
    if (input.contains('a') ||
        input.contains('ay') ||
        input.contains('hey') ||
        input.contains('eight') ||
        input.contains('ace')) {
      print("TEAM A DETECTED in: '$input'");
      incrementScore('A');
      return;
    }

    if (input.contains('b') ||
        input.contains('be') ||
        input.contains('bee') ||
        input.contains('me') ||
        input.contains('de')) {
      print("TEAM B DETECTED in: '$input'");
      incrementScore('B');
      return;
    }

    if (input.contains('reset') ||
        input.contains('restart') ||
        input.contains('clear')) {
      resetGame();
    }
  }

  void incrementScore(String team) {
    setState(() {
      if (team == 'A') {
        scoreA++;
        info = "Point for Team A!";
      } else {
        scoreB++;
        info = "Point for Team B!";
      }

      // Speak the current score
      _speak("Point for Team ${team}. Score is $scoreA to $scoreB");

      checkSetWinner();
    });
  }

  void checkSetWinner() {
    // Need to reach at least the points per set
    if ((scoreA >= pointsPerSet || scoreB >= pointsPerSet) &&
        // Need a 2-point lead to win
        (scoreA - scoreB).abs() >= 2) {

      if (scoreA > scoreB) {
        setsWonA++;
        info = "Team A wins Set $currentSet!";
        _speak("Team A wins Set $currentSet!");
      } else {
        setsWonB++;
        info = "Team B wins Set $currentSet!";
        _speak("Team B wins Set $currentSet!");
      }

      // Check if match is over (best of N sets)
      int setsToWin = (numSets / 2).ceil();
      if (setsWonA >= setsToWin || setsWonB >= setsToWin) {
        gameActive = false;
        String winner = setsWonA > setsWonB ? "Team A" : "Team B";
        info = "Match Over. $winner Wins!";
        _speak("Match Over. $winner Wins!");
        stopListening();
      } else {
        // Start next set
        currentSet++;
        scoreA = 0;
        scoreB = 0;
      }
    }
  }

  void resetGame() {
    setState(() {
      scoreA = scoreB = setsWonA = setsWonB = 0;
      currentSet = 1;
      gameActive = true;
      info = "Game Started!";
      recognitionHistory.clear();
      _speak("Game Started!");

      // Start listening when game starts
      if (!_isListening) {
        startListening();
      }
    });
  }

  void _speak(String text) async {
    await _flutterTts.speak(text);
  }

  // Manual score buttons
  Widget buildScoreButton(String team) {
    return ElevatedButton(
      onPressed: () => incrementScore(team),
      child: Text("+1 for Team $team", style: TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: team == 'A' ? Colors.blue : Colors.red,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  Widget buildTeamColumn(String team, int score, int setsWon) {
    bool isTeamA = team == "Team A";
    return Expanded(
      child: Container(
        margin: EdgeInsets.all(8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isTeamA ? Colors.blue[100] : Colors.red[100],
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Text(team, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('$score',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: isTeamA ? Colors.blue[800] : Colors.red[800],
              )
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isTeamA ? Colors.blue[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Sets Won: $setsWon',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
              ),
            ),
            SizedBox(height: 16),
            buildScoreButton(isTeamA ? 'A' : 'B'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Table Tennis Scoreboard'),
        actions: [
          if (_isListening)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.mic, color: Colors.red),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!gameActive)
              Column(children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Number of Sets',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => numSets = int.tryParse(value) ?? 3,
                ),
                SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Points per Set',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => pointsPerSet = int.tryParse(value) ?? 11,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: resetGame,
                  child: Text('Start Game', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                ),
              ]),
            if (gameActive) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Set $currentSet of $numSets',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  buildTeamColumn("Team A", scoreA, setsWonA),
                  buildTeamColumn("Team B", scoreB, setsWonB),
                ],
              ),
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  info,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 24),
                    label: Text(_isListening ? 'Voice Active' : 'Start Voice', style: TextStyle(fontSize: 16)),
                    onPressed: _isListening ? stopListening : startListening,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening ? Colors.green : Colors.blue,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: Icon(Icons.refresh, size: 24),
                    label: Text("Reset Game", style: TextStyle(fontSize: 16)),
                    onPressed: () => setState(() => gameActive = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (_isListening)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Voice Commands Active',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Say "A" or "B" to add points',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Last heard: "$lastHeard"',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Recent recognition history:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      ...recognitionHistory.map((text) => Text(
                        '• "$text"',
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                      )).toList(),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}