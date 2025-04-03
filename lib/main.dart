import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(const ChatterboxApp());
}

class ChatterboxApp extends StatelessWidget {
  const ChatterboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chatterbox',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ChatterboxHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ChatterboxHomePage extends StatefulWidget {
  const ChatterboxHomePage({super.key});

  @override
  State<ChatterboxHomePage> createState() => _ChatterboxHomePageState();
}

class _ChatterboxHomePageState extends State<ChatterboxHomePage> {
  bool _isRecording = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _recognizedText = '';
  html.MediaRecorder? _mediaRecorder;
  List<html.Blob> _audioChunks = [];
  String? _audioUrl;

  Future<void> startRecording() async {
    // Initialise speech recognition
    bool available = await _speech.initialize();
    if (available) {
      _speech.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
          });
        },
      );
    } else {
      debugPrint('Speech recognition unavailable');
    }

    // Request microphone access and start audio recording.
    try {
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': true,
      });
      if (stream != null) {
        _audioChunks = [];
        _mediaRecorder = html.MediaRecorder(stream);
        _mediaRecorder!.addEventListener('dataavailable', (event) {
          final blobEvent = event as html.BlobEvent;
          _audioChunks.add(blobEvent.data!);
        });
        _mediaRecorder!.addEventListener('stop', (event) {
          final blob = html.Blob(_audioChunks, 'audio/webm');
          final url = html.Url.createObjectUrl(blob);
          setState(() {
            _audioUrl = url;
          });
        });
        _mediaRecorder!.start();
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }

    setState(() {
      _isRecording = true;
    });
  }

  Future<void> stopRecording() async {
    // Stop speech recognition.
    _speech.stop();

    // Stop audio recording.
    try {
      if (_mediaRecorder != null && _mediaRecorder!.state == 'recording') {
        _mediaRecorder!.stop();
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }

    setState(() {
      _isRecording = false;
    });
  }

  void chatterShatter() {
    setState(() {
      _recognizedText = '';
      if (_audioUrl != null) {
        html.Url.revokeObjectUrl(_audioUrl!);
      }
      _audioUrl = null;
    });
  }

  void playRecording() {
    if (_audioUrl != null) {
      // Create an AudioElement, set autoplay and attach it to the DOM
      final audio =
          html.AudioElement(_audioUrl!)
            ..autoplay = true
            ..controls = false;
      html.document.body?.append(audio);
      audio.play().catchError((error) {
        debugPrint('Error playing audio: $error');
      });
      // Remove the element once playback finishes
      audio.onEnded.listen((event) {
        audio.remove();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(title: const Text('Chatterbox')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              '>',
              style: TextStyle(fontSize: 100, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Blue speech bubble with centred text.
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              constraints: BoxConstraints(
                minWidth: 200,
                maxWidth: size.width * 0.8,
              ),
              decoration: BoxDecoration(
                color: Colors.blue[300],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _recognizedText.isNotEmpty
                    ? _recognizedText
                    : (_isRecording
                        ? 'Listening...'
                        : 'Your words appear here'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isRecording ? stopRecording : startRecording,
                  child: Text(_isRecording ? 'Stop' : 'Record'),
                ),
                const SizedBox(width: 10),
                // Chatter Shatter only enabled when not recording.
                ElevatedButton(
                  onPressed: !_isRecording ? chatterShatter : null,
                  child: const Text('Chatter Shatter'),
                ),
                const SizedBox(width: 10),
                // Play button only enabled when not recording and audio is available.
                ElevatedButton(
                  onPressed:
                      (!_isRecording && _audioUrl != null)
                          ? playRecording
                          : null,
                  child: const Text('Play'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
