import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData, SystemNavigator;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const MyApp());
}

// Global theme notifier so any widget (HomeScreen) can toggle the app theme
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);

// ====================================================================
// 1. ROOT WIDGET: MANAGES THEME STATE
// ====================================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  late final ThemeData lightTheme;
  late final ThemeData darkTheme;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    lightTheme = ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.deepPurple,
      primaryColor: Colors.deepPurple[700],
      colorScheme: const ColorScheme.light(
        primary: Colors.deepPurple,
        secondary: Colors.orange,
      ),
      scaffoldBackgroundColor: Colors.deepPurple[50],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.deepPurple[700],
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: Colors.grey[500]),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xff212121)),
        bodyMedium: TextStyle(color: Color(0xff424242)),
      ),
      dividerColor: Colors.grey[300],
      useMaterial3: true,
    );
    darkTheme = ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.deepPurple,
      primaryColor: const Color.fromARGB(255, 0, 0, 0),
      colorScheme: ColorScheme.dark(
        primary: Colors.deepPurple[300]!,
        secondary: Colors.orange[300]!,
        surface: const Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E1E1E),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.white.withOpacity(0.87)),
        bodyMedium: TextStyle(color: Colors.white.withOpacity(0.60)),
      ),
      dividerColor: Colors.grey[600],
      iconTheme: const IconThemeData(color: Colors.white),
      primaryIconTheme: const IconThemeData(color: Colors.white),
      useMaterial3: true,
    );
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode');
    if (saved == 'dark') {
      appThemeMode.value = ThemeMode.dark;
    } else {
      appThemeMode.value = ThemeMode.light;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, child) {
        return MaterialApp(
          title: 'Tamil Romanized Bible App',
          home: const SplashScreen(),
          builder: (context, child) => AnimatedTheme(
            data: mode == ThemeMode.dark ? darkTheme : lightTheme,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

// ====================================================================
// 2. SPLASH SCREEN WIDGET
// ====================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _goToHome();
  }

  void _goToHome() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use fixed black text on the white splash for consistent appearance.
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Jesus Chosen Generation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Powered by Jesus Grace',
                style: TextStyle(fontSize: 14, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// 3. HOME SCREEN WIDGET
// ====================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  double _fontSize = 18.0;
  int _selectedBookIndex = 0;
  int _selectedChapter = 1;
  late TabController _tabController;
  TabController? _subTabController;
  int _defaultTab = 0;
  List<Map<String, dynamic>> _bookmarks = [];
  List<Map<String, dynamic>> _notes = [];
  late ScrollController _romanizedScrollController;
  late ScrollController _tamilScrollController;
  Map<String, dynamic> _bibleData = {'books': []};
  List<Map<String, dynamic>> _filteredVerses = [];
  final Map<String, GlobalKey> _verseKeys = {};
  bool _isSelectionMode = false;
  final Set<int> _selectedVerses = {};
  late FlutterTts _flutterTts;
  DateTime? _lastBackPressed;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isAudioPlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _subTabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _romanizedScrollController = ScrollController();
    _tamilScrollController = ScrollController();
    _flutterTts = FlutterTts();
    _initTts();
    _loadBibleData().then((_) {
      _loadSettings().then((_) {
        setState(() {
          _tabController.index = _defaultTab;
        });
      });
    });
  }

  void _initTts() {
    _flutterTts.setLanguage('en-US');
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isAudioPlaying = false;
      });
    });
  }

  void _readAloud(String text) async {
    await _flutterTts.stop();
    setState(() {
      _isAudioPlaying = true;
    });
    await _flutterTts.speak(text);
  }

  void _stopAudio() async {
    await _flutterTts.stop();
    setState(() {
      _isAudioPlaying = false;
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _tabController.dispose();
    _subTabController?.dispose();
    _romanizedScrollController.dispose();
    _tamilScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final newMode = appThemeMode.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    appThemeMode.value = newMode;
    await prefs.setString(
      'themeMode',
      newMode == ThemeMode.dark ? 'dark' : 'light',
    );
    if (mounted) setState(() {});
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFontSize = prefs.getDouble('fontSize');
    if (savedFontSize != null) {
      _fontSize = savedFontSize;
    }
    final savedDefaultTab = prefs.getInt('defaultTab');
    if (savedDefaultTab != null) {
      _defaultTab = savedDefaultTab;
    }
    final savedBookmarks = prefs.getStringList('bookmarks');
    if (savedBookmarks != null) {
      _bookmarks = savedBookmarks
          .map((item) => json.decode(item) as Map<String, dynamic>)
          .where((bookmark) {
        final bookName = bookmark['book'] as String;
        final chapter = bookmark['chapter'] as int;
        final verse = bookmark['verse'] as int;
        final bookExists = (_bibleData['books'] as List?)?.any(
              (b) => b['name'] == bookName,
            ) ??
            false;
        if (!bookExists && _bibleData['books'].isNotEmpty) return false;
        final book = (_bibleData['books'] as List).firstWhere(
          (b) => b['name'] == bookName,
          orElse: () => null,
        );
        if (book == null) return false;
        final chapterExists = (book['chapters'] as List?)?.any(
              (c) => c['number'] == chapter,
            ) ??
            false;
        if (!chapterExists) return false;
        final verses = (book['chapters'] as List).firstWhere(
          (c) => c['number'] == chapter,
          orElse: () => {'verses': []},
        )['verses'] as List;
        return verses.any((v) => v['number'] == verse);
      }).toList();
    }
    final savedNotes = prefs.getStringList('notes');
    if (savedNotes != null) {
      _notes = savedNotes
          .map((item) => json.decode(item) as Map<String, dynamic>)
          .toList();
    }
    setState(() {});
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setInt('defaultTab', _defaultTab);
    final bookmarkStrings =
        _bookmarks.map((item) => json.encode(item)).toList();
    await prefs.setStringList('bookmarks', bookmarkStrings);
    final noteStrings = _notes.map((item) => json.encode(item)).toList();
    await prefs.setStringList('notes', noteStrings);
  }

  void _saveFontSize(double newSize) {
    setState(() {
      _fontSize = newSize;
    });
    _saveSettings();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedVerses.clear();
      }
    });
  }

  void _toggleVerseSelection(int verseNumber) {
    setState(() {
      if (_selectedVerses.contains(verseNumber)) {
        _selectedVerses.remove(verseNumber);
      } else {
        _selectedVerses.add(verseNumber);
      }
    });
  }

  void _bookmarkSelectedVerses(bool isTamil) {
    final bookName = (_bibleData['books'] as List?)?[_selectedBookIndex]
                ?['name']
            ?.toString() ??
        'Unknown Book';
    final language = isTamil ? 'tamil' : 'romanized';
    final sortedVerses = _selectedVerses.toList()..sort();

    final combinedText = sortedVerses.map((verseNumber) {
      final verse = _filteredVerses.firstWhere(
        (v) => v['number'] == verseNumber,
        orElse: () => {},
      );
      final text = language == 'tamil' ? verse['tamil'] : verse['romanized'];
      return '$verseNumber. $text';
    }).join('\n\n');

    final verseRange = sortedVerses.length == 1
        ? '${sortedVerses.first}'
        : '${sortedVerses.first}-${sortedVerses.last}';

    final bookmarkKey =
        '${bookName}_${_selectedChapter}_${verseRange}_$language';

    _bookmarks.add({
      'key': bookmarkKey,
      'book': bookName,
      'chapter': _selectedChapter,
      'verse': sortedVerses.first,
      'text': combinedText,
      'language': language,
      'note': '',
    });

    _saveSettings();
    setState(() {
      _isSelectionMode = false;
      _selectedVerses.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${sortedVerses.length} verses bookmarked as one'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _copySelectedVerses(bool isTamil) {
    final bookName = (_bibleData['books'] as List?)?[_selectedBookIndex]
                ?['name']
            ?.toString() ??
        'Unknown Book';
    final language = isTamil ? 'tamil' : 'romanized';
    final languageLabel = isTamil ? 'Tamil' : 'Romanized';
    final sortedVerses = _selectedVerses.toList()..sort();

    final combinedText = sortedVerses.map((verseNumber) {
      final verse = _filteredVerses.firstWhere(
        (v) => v['number'] == verseNumber,
        orElse: () => {},
      );
      final text = language == 'tamil' ? verse['tamil'] : verse['romanized'];
      return '$verseNumber. $text';
    }).join('\n\n');

    final verseRange = sortedVerses.length == 1
        ? '${sortedVerses.first}'
        : '${sortedVerses.first}-${sortedVerses.last}';

    final shareText =
        '($languageLabel) $bookName $_selectedChapter:$verseRange\n\n$combinedText';

    Clipboard.setData(ClipboardData(text: shareText)).then((_) {
      setState(() {
        _isSelectionMode = false;
        _selectedVerses.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${sortedVerses.length} verses copied!'),
          duration: const Duration(seconds: 1),
        ),
      );
    });
  }

  void _readAloudSelectedVerses(bool isTamil) {
    final sortedVerses = _selectedVerses.toList()..sort();

    final combinedText = sortedVerses.map((verseNumber) {
      final verse = _filteredVerses.firstWhere(
        (v) => v['number'] == verseNumber,
        orElse: () => {},
      );
      return verse['tamil']?.toString() ?? '';
    }).join('. ');

    _readAloud(combinedText);
    setState(() {
      _isSelectionMode = false;
      _selectedVerses.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reading ${sortedVerses.length} verses aloud'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Future<void> _loadBibleData() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/bible_data.json',
      );
      final Map<String, dynamic> decodedData = json.decode(jsonString);
      setState(() {
        _bibleData = decodedData;
        _isLoading = false;
      });
      _initializeFilteredVerses();
    } catch (e) {
      debugPrint('Error loading or decoding bible data: $e');
      setState(() {
        _bibleData = {'books': []};
        _isLoading = false;
      });
    }
  }

  void _handleTabChange() {
    debugPrint('Tab changed to index: ${_tabController.index}');
    if (_tabController.indexIsChanging) {
      _loadCurrentVerses();
    }
    // Ensure the widget rebuilds when the tab changes so UI elements
    // (like the bottom bar) update their visibility immediately.
    if (mounted) setState(() {});
  }

  void _initializeFilteredVerses() {
    if (_bibleData['books'] == null || (_bibleData['books'] as List).isEmpty) {
      _filteredVerses = [];
      return;
    }
    try {
      _verseKeys.clear();
      debugPrint('Cleared verse keys');
      final books = _bibleData['books'] as List;
      if (_selectedBookIndex >= books.length) _selectedBookIndex = 0;
      final book = books[_selectedBookIndex];
      final chapters = book['chapters'] as List;
      final availableChapters =
          chapters.map((ch) => ch['number'] as int).toList();
      if (!availableChapters.contains(_selectedChapter)) {
        _selectedChapter =
            availableChapters.isNotEmpty ? availableChapters.first : 1;
      }
      final chapter = chapters.firstWhere(
        (ch) => ch['number'] == _selectedChapter,
        orElse: () => chapters.first,
      );
      _filteredVerses =
          (chapter['verses'] as List? ?? []).cast<Map<String, dynamic>>();
      debugPrint('Initialized verses: ${_filteredVerses.length} verses loaded');
    } catch (e) {
      debugPrint('Error initializing filtered verses: $e');
      _filteredVerses = [];
    }
  }

  void _loadCurrentVerses() {
    setState(() {
      _initializeFilteredVerses();
    });
  }

  void _toggleBookmark(
    Map<String, dynamic> verse,
    String language,
    String bookName,
  ) {
    final verseNumber = verse['number'] as int? ?? 0;
    final bookmarkKey =
        '${bookName}_${_selectedChapter}_${verseNumber}_$language';
    final existingIndex = _bookmarks.indexWhere((b) => b['key'] == bookmarkKey);
    if (existingIndex != -1) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Bookmark'),
          content: Text(
            'Remove bookmark for $bookName $_selectedChapter:$verseNumber?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _bookmarks.removeAt(existingIndex);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Bookmark Removed: $bookName $_selectedChapter:$verseNumber (${language.toUpperCase()})',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _bookmarks.add({
          'key': bookmarkKey,
          'book': bookName,
          'chapter': _selectedChapter,
          'verse': verseNumber,
          'text': language == 'tamil' ? verse['tamil'] : verse['romanized'],
          'language': language,
          'note': '',
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bookmark Added: $bookName $_selectedChapter:$verseNumber (${language.toUpperCase()})',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
    _saveSettings();
  }

  bool _isBookmarked(
    String bookName,
    int chapter,
    int verseNumber,
    String language,
  ) {
    final key = '${bookName}_${chapter}_${verseNumber}_$language';
    return _bookmarks.any((b) => b['key'] == key);
  }

  bool _isPartOfMultipleBookmark(
    String bookName,
    int chapter,
    int verseNumber,
    String language,
  ) {
    return _bookmarks.any((bookmark) {
      if (bookmark['book'] != bookName ||
          bookmark['chapter'] != chapter ||
          bookmark['language'] != language) {
        return false;
      }
      final key = bookmark['key'] as String;
      if (key.contains('-')) {
        final parts = key.split('_');
        if (parts.length >= 3) {
          final rangePart = parts[2];
          if (rangePart.contains('-')) {
            final rangeParts = rangePart.split('-');
            if (rangeParts.length == 2) {
              final start = int.tryParse(rangeParts[0]) ?? 0;
              final end = int.tryParse(rangeParts[1]) ?? 0;
              return verseNumber >= start && verseNumber <= end;
            }
          }
        }
      }
      return false;
    });
  }

  void _showBookSelector(List<Map<String, dynamic>> books) {
    final scrollController = ScrollController(
      initialScrollOffset: _selectedBookIndex * 60.0,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Book',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  final isSelected = index == _selectedBookIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedBookIndex = index;
                        _selectedChapter = 1;
                      });
                      _initializeFilteredVerses();
                      _loadCurrentVerses();
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_romanizedScrollController.hasClients) {
                          _romanizedScrollController.jumpTo(0);
                        }
                        if (_tamilScrollController.hasClients) {
                          _tamilScrollController.jumpTo(0);
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        book['name']?.toString() ?? 'Unknown',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
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

  void _showChapterSelector(List<int> availableChapters) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Chapter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: availableChapters.length,
                itemBuilder: (context, index) {
                  final chapter = availableChapters[index];
                  final isSelected = chapter == _selectedChapter;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedChapter = chapter;
                      });
                      _initializeFilteredVerses();
                      _loadCurrentVerses();
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_romanizedScrollController.hasClients) {
                          _romanizedScrollController.jumpTo(0);
                        }
                        if (_tamilScrollController.hasClients) {
                          _tamilScrollController.jumpTo(0);
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$chapter',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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

  void _navigateToVerse(Map<String, dynamic> bookmarkItem) {
    if (!mounted) {
      debugPrint('Widget not mounted, aborting navigation');
      return;
    }
    // Do not pop the navigator here — this method is used from the
    // Bookmarks tab. Popping would close the HomeScreen and produce a
    // black screen. If callers need to close a modal they should do so
    // before calling this method.
    final bookName = bookmarkItem['book'] as String;
    debugPrint(
      'Navigating to bookmark: $bookName ${bookmarkItem['chapter']}:${bookmarkItem['verse']} (${bookmarkItem['language']})',
    );
    final targetBookIndex = (_bibleData['books'] as List).indexWhere(
      (book) => book['name'] == bookName,
    );
    if (targetBookIndex == -1) {
      debugPrint('Book not found: $bookName');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Book "$bookName" not found')));
      return;
    }
    final targetChapter = bookmarkItem['chapter'] as int;
    final targetVerseNumber = bookmarkItem['verse'] as int;
    final isTamil = bookmarkItem['language'] == 'tamil';
    final targetTabIndex = isTamil ? 1 : 0;
    final book = (_bibleData['books'] as List)[targetBookIndex];
    final chapter = (book['chapters'] as List).firstWhere(
      (c) => c['number'] == targetChapter,
      orElse: () => null,
    );
    if (chapter == null) {
      debugPrint('Chapter not found: $targetChapter in $bookName');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chapter $targetChapter not found in $bookName'),
        ),
      );
      return;
    }
    final verseExists = (chapter['verses'] as List).any(
      (v) => v['number'] == targetVerseNumber,
    );
    if (!verseExists) {
      debugPrint(
        'Verse not found: $targetVerseNumber in $bookName $targetChapter',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verse $targetVerseNumber not found in $bookName $targetChapter',
          ),
        ),
      );
      return;
    }
    setState(() {
      _selectedBookIndex = targetBookIndex;
      _selectedChapter = targetChapter;
      _initializeFilteredVerses();
      debugPrint(
        'State updated: BookIndex=$targetBookIndex, Chapter=$targetChapter, Tab=$targetTabIndex',
      );
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) {
        debugPrint('Widget unmounted during delayed navigation');
        return;
      }
      _tabController.index = targetTabIndex;
      debugPrint('Tab switched to index: $targetTabIndex');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          debugPrint('Widget unmounted during post-frame callback');
          return;
        }
        final targetController =
            isTamil ? _tamilScrollController : _romanizedScrollController;
        if (targetController.hasClients) {
          final verseKey = _verseKeys[
              '${bookName}_${targetChapter}_${targetVerseNumber}_${isTamil ? 'tamil' : 'romanized'}'];
          if (verseKey != null && verseKey.currentContext != null) {
            try {
              Scrollable.ensureVisible(
                verseKey.currentContext!,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                alignment: 0.1,
              ).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Navigated to $bookName $targetChapter:$targetVerseNumber',
                    ),
                  ),
                );
              });
              return;
            } catch (e) {
              debugPrint('ensureVisible failed, falling back to animateTo: $e');
            }
          }
          // Fallback: estimate position and animate
          final offset = (targetVerseNumber - 1) * 100.0;
          debugPrint('Scrolling to estimated offset: $offset');
          targetController
              .animateTo(
            offset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          )
              .then((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Navigated to $bookName $targetChapter:$targetVerseNumber',
                ),
              ),
            );
          });
        } else {
          debugPrint('ScrollController has no clients');
        }
      });
    });
  }

  Widget _buildVerseItem(Map<String, dynamic> verse, {required bool isTamil}) {
    final verseNumber = verse['number'] as int? ?? 0;
    final text =
        (isTamil ? verse['tamil'] : verse['romanized'])?.toString() ?? '';
    final bookName = (_bibleData['books'] as List?)?[_selectedBookIndex]
                ?['name']
            ?.toString() ??
        'Unknown Book';
    final language = isTamil ? 'tamil' : 'romanized';
    final verseKey = GlobalKey();
    _verseKeys['${bookName}_${_selectedChapter}_${verseNumber}_$language'] =
        verseKey;
    final isBookmarked =
        _isBookmarked(bookName, _selectedChapter, verseNumber, language) ||
            _isPartOfMultipleBookmark(
              bookName,
              _selectedChapter,
              verseNumber,
              language,
            );

    return Column(
      key: verseKey,
      children: [
        InkWell(
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedVerses.add(verseNumber);
              });
            }
          },
          onTap: () {
            if (_isSelectionMode) {
              _toggleVerseSelection(verseNumber);
            } else {
              _showVerseMenu(context, verse, isTamil);
            }
          },
          child: Container(
            color: _isSelectionMode && _selectedVerses.contains(verseNumber)
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : isBookmarked
                    ? Theme.of(context).colorScheme.secondary.withOpacity(0.05)
                    : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16.0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isSelectionMode)
                    Checkbox(
                      value: _selectedVerses.contains(verseNumber),
                      onChanged: (_) => _toggleVerseSelection(verseNumber),
                    ),
                  // Verse number with no color highlighting
                  Container(
                    padding: const EdgeInsets.all(6),
                    margin: EdgeInsets.only(
                      right: 12,
                      top: 2,
                      left: _isSelectionMode ? 0 : 0,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$verseNumber',
                      style: TextStyle(
                        fontSize: _fontSize * 0.8,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: _fontSize,
                        height: 1.6,
                        fontFamily: isTamil ? 'Noto Sans Tamil' : 'Roboto',
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withAlpha(128),
          ),
        ),
      ],
    );
  }

  void _addBookmarkWithNote(
    Map<String, dynamic> verse,
    String language,
    String bookName,
  ) {
    final verseNumber = verse['number'] as int? ?? 0;
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Note for $bookName $_selectedChapter:$verseNumber'),
        content: TextField(
          controller: noteController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Add your note here...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final bookmarkKey =
                  '${bookName}_${_selectedChapter}_${verseNumber}_$language';
              setState(() {
                _bookmarks.add({
                  'key': bookmarkKey,
                  'book': bookName,
                  'chapter': _selectedChapter,
                  'verse': verseNumber,
                  'text':
                      language == 'tamil' ? verse['tamil'] : verse['romanized'],
                  'language': language,
                  'note': noteController.text,
                });
              });
              _saveSettings();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Bookmark with note added: $bookName $_selectedChapter:$verseNumber',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showNoteDialog(Map<String, dynamic> bookmark) {
    final noteController = TextEditingController(text: bookmark['note'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Note for ${bookmark['book']} ${bookmark['chapter']}:${bookmark['verse']}',
        ),
        content: TextField(
          controller: noteController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Add your note here...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (bookmark['note']?.toString().isNotEmpty ?? false)
            TextButton(
              onPressed: () {
                setState(() {
                  bookmark['note'] = '';
                });
                _saveSettings();
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(
                  content: Text('Note removed'),
                  duration: Duration(seconds: 1),
                ));
              },
              child: const Text('Remove Note'),
            ),
          TextButton(
            onPressed: () {
              setState(() {
                bookmark['note'] = noteController.text;
              });
              _saveSettings();
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(
                content: Text('Note saved'),
                duration: Duration(seconds: 1),
              ));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showVerseMenu(
    BuildContext context,
    Map<String, dynamic> verse,
    bool isTamil,
  ) {
    final bookName = (_bibleData['books'] as List?)?[_selectedBookIndex]
                ?['name']
            ?.toString() ??
        'Unknown Book';
    final language = isTamil ? 'tamil' : 'romanized';
    final verseNumber = verse['number'] as int? ?? 0;
    final isBookmarked = _isBookmarked(
      bookName,
      _selectedChapter,
      verseNumber,
      language,
    );
    final bookmarkKey =
        '${bookName}_${_selectedChapter}_${verseNumber}_$language';
    final bookmark = _bookmarks.firstWhere(
      (b) => b['key'] == bookmarkKey,
      orElse: () => {},
    );

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(
                  isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                  color: isBookmarked
                      ? Theme.of(context).colorScheme.secondary
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Theme.of(context).primaryColor),
                ),
                title: Text(isBookmarked ? 'Remove Bookmark' : 'Add Bookmark'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleBookmark(verse, language, bookName);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.note_add,
                  color: isBookmarked &&
                          (bookmark['note']?.toString().isNotEmpty ?? false)
                      ? Theme.of(context).colorScheme.secondary
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Theme.of(context).primaryColor),
                ),
                title: Text(isBookmarked ? 'Edit Note' : 'Add Note'),
                onTap: () {
                  Navigator.pop(context);
                  if (isBookmarked) {
                    _showNoteDialog(bookmark);
                  } else {
                    _addBookmarkWithNote(verse, language, bookName);
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.copy,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Theme.of(context).primaryColor,
                ),
                title: const Text('Copy Verse'),
                onTap: () {
                  Navigator.pop(context);
                  final languageLabel = isTamil ? 'Tamil' : 'Romanized';
                  final text = (isTamil ? verse['tamil'] : verse['romanized'])
                          ?.toString() ??
                      '';
                  final shareText =
                      '($languageLabel) $bookName $_selectedChapter:$verseNumber\n"$text"';
                  Clipboard.setData(ClipboardData(text: shareText)).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Verse copied!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  });
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.volume_up,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Theme.of(context).primaryColor,
                ),
                title: const Text('Read Aloud'),
                onTap: () {
                  Navigator.pop(context);
                  final text = verse['tamil']?.toString() ?? '';
                  _readAloud(text);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageView({required bool isTamil}) {
    final displayVerses = _searchQuery.isEmpty
        ? _filteredVerses
        : _filteredVerses.where((verse) {
            final text = isTamil ? verse['tamil'] : verse['romanized'];
            return text
                .toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
          }).toList();
    final bookName = (_bibleData['books'] as List?)?[_selectedBookIndex]
                ?['name']
            ?.toString() ??
        'Unknown';

    return Column(
      children: [
        if (_isSearching)
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).cardColor,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search verses...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _isSearching = false;
                    });
                  },
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        if (_isSelectionMode)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.15),
                  Theme.of(context).primaryColor.withOpacity(0.05)
                ],
              ),
              border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      width: 2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedVerses.isEmpty
                        ? null
                        : () => _bookmarkSelectedVerses(isTamil),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bookmark_add, size: 20),
                        const SizedBox(height: 4),
                        Text('${_selectedVerses.length}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedVerses.isEmpty
                        ? null
                        : () => _copySelectedVerses(isTamil),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 20),
                        SizedBox(height: 4),
                        Text('Copy', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedVerses.isEmpty
                        ? null
                        : () => _readAloudSelectedVerses(isTamil),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up, size: 20),
                        SizedBox(height: 4),
                        Text('Read', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _toggleSelectionMode,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 20),
                        SizedBox(height: 4),
                        Text('Exit', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: displayVerses.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'No verses in this chapter'
                        : 'No results found',
                    style: TextStyle(color: Colors.grey, fontSize: _fontSize),
                  ),
                )
              : ListView.builder(
                  controller: isTamil
                      ? _tamilScrollController
                      : _romanizedScrollController,
                  padding: const EdgeInsets.only(top: 0, bottom: 72),
                  itemCount: displayVerses.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book,
                                size: 16,
                                color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              '$bookName $_selectedChapter',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final verse = displayVerses[index - 1];
                    return _buildVerseItem(verse, isTamil: isTamil);
                  },
                ),
        ),
      ],
    );
  }

  void _addNote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddNoteScreen(
          onNoteSaved: (note) {
            setState(() {
              _notes.add(note);
            });
            _saveSettings();
          },
        ),
      ),
    );
  }

  void _viewNote(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(note['title'] ?? 'Untitled'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.6,
          child: SingleChildScrollView(
            child: Text(
              note['content'] ?? '',
              style: TextStyle(fontSize: _fontSize),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editNote(note);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _showDeleteBookmarkDialog(Map<String, dynamic> bookmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bookmark'),
        content: Text(
            'Delete bookmark for ${bookmark['book']} ${bookmark['chapter']}:${bookmark['verse']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _bookmarks.removeWhere((b) => b['key'] == bookmark['key']);
              });
              _saveSettings();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeleteNoteDialog(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Delete "${note['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _notes.removeWhere((n) => n['id'] == note['id']);
              });
              _saveSettings();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editNote(Map<String, dynamic> note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddNoteScreen(
          existingNote: note,
          onNoteSaved: (updatedNote) {
            setState(() {
              final index = _notes.indexWhere((n) => n['id'] == note['id']);
              if (index != -1) {
                _notes[index] = updatedNote;
              }
            });
            _saveSettings();
          },
          onNoteDeleted: () {
            setState(() {
              _notes.removeWhere((n) => n['id'] == note['id']);
            });
            _saveSettings();
          },
        ),
      ),
    );
  }

  Widget _buildNotesView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addNote,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Note'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_notes.length} notes',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.note_add,
                          size: 48,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No notes yet',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: _fontSize + 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first note to capture\nyour thoughts and reflections',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: _fontSize - 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _notes.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Column(
                          children: [
                            Text(
                              'Jesus Chosen Generation',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Powered by Jesus Grace',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    final note = _notes[index];
                    final category = note['category'] ?? 'Personal';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => _editNote(note),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(category),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getCategoryIcon(category),
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          category,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatNoteDate(
                                        note['updatedAt'] ?? note['createdAt']),
                                    style: TextStyle(
                                      fontSize: _fontSize - 6,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                note['title'] ?? 'Untitled',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: _fontSize + 2,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (note['content']?.toString().isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 8),
                                Text(
                                  note['content'],
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: _fontSize - 2,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color,
                                    height: 1.4,
                                  ),
                                ),
                              ],
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
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Personal':
        return Icons.person;
      case 'Study':
        return Icons.school;
      case 'Prayer':
        return Icons.favorite;
      case 'Sermon':
        return Icons.mic;
      case 'Reflection':
        return Icons.lightbulb;
      default:
        return Icons.note;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Personal':
        return Colors.blue;
      case 'Study':
        return Colors.green;
      case 'Prayer':
        return Colors.purple;
      case 'Sermon':
        return Colors.orange;
      case 'Reflection':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _formatNoteDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildLibraryView() {
    return Column(
      children: [
        Expanded(
          child: TabBarView(
            controller: _subTabController!,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildBookmarksView(),
              _buildNotesView(),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: Theme.of(context).cardColor,
            child: TabBar(
              controller: _subTabController!,
              indicatorColor: Theme.of(context).colorScheme.secondary,
              labelColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Theme.of(context).primaryColor,
              unselectedLabelColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.grey,
              tabs: [
                Tab(
                  icon: Icon(Icons.bookmark),
                  text: 'Bookmarks (${_bookmarks.length})',
                ),
                Tab(
                  icon: Icon(Icons.note),
                  text: 'Notes (${_notes.length})',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookmarksView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.bookmark,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your Bookmarked Verses',
                  style: TextStyle(
                    fontSize: _fontSize + 2,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_bookmarks.length}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _bookmarks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bookmark_border,
                          size: 48,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No bookmarks yet',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: _fontSize + 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Long press any verse to bookmark it\nfor quick access later',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: _fontSize - 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookmarks.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _bookmarks.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Column(
                          children: [
                            Text(
                              'Jesus Chosen Generation',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Powered by Jesus Grace',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    final bookmarkItem = _bookmarks[index];
                    final isTamil = bookmarkItem['language'] == 'tamil';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => _navigateToVerse(bookmarkItem),
                        onLongPress: () =>
                            _showDeleteBookmarkDialog(bookmarkItem),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isTamil ? Colors.orange : Colors.blue,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isTamil ? 'தமிழ்' : 'Romanized',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(
                                      Icons.note_add,
                                      color: (bookmarkItem['note']
                                                  ?.toString()
                                                  .isNotEmpty ??
                                              false)
                                          ? Theme.of(context)
                                              .colorScheme
                                              .secondary
                                          : Colors.grey,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showNoteDialog(bookmarkItem),
                                    tooltip: 'Add/Edit Note',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${bookmarkItem['book']} ${bookmarkItem['chapter']}:${bookmarkItem['verse']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: _fontSize + 2,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                bookmarkItem['text']?.toString() ?? '',
                                style: TextStyle(
                                  fontSize: _fontSize - 1,
                                  height: 1.5,
                                  fontFamily:
                                      isTamil ? 'Noto Sans Tamil' : 'Roboto',
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                                ),
                              ),
                              if (bookmarkItem['note']?.toString().isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.note,
                                        size: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          bookmarkItem['note']?.toString() ??
                                              '',
                                          style: TextStyle(
                                            fontSize: _fontSize - 3,
                                            fontStyle: FontStyle.italic,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
  }

  Widget _buildBottomBar(
    List<Map<String, dynamic>> books,
    List<int> availableChapters,
    Color bottomBarColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: bottomBarColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.menu_book, size: 14, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          'Book:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _showBookSelector(books),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white30),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                books[_selectedBookIndex]['name']?.toString() ??
                                    'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.format_list_numbered,
                          size: 14,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Chapter:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _showChapterSelector(availableChapters),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white30),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$_selectedChapter',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Data...')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Fetching Bible data...'),
            ],
          ),
        ),
      );
    }

    final books = _bibleData['books'] as List? ?? [];
    if (books.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('Failed to load Bible data or data is empty.'),
        ),
      );
    }

    final book = books[_selectedBookIndex];
    final bookName = book['name']?.toString() ?? 'No Books Available';
    final chapters = (book['chapters'] as List?) ?? [];
    final availableChapters =
        chapters.map((ch) => ch['number'] as int? ?? 0).toList();
    final bottomBarColor = Theme.of(context).primaryColor;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '$bookName ${_tabController.index < 2 ? _selectedChapter : ''}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_tabController.index < 2)
              IconButton(
                icon: Icon(_isSearching ? Icons.search_off : Icons.search,
                    size: 20),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            IconButton(
              icon: const Icon(Icons.settings, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      fontSize: _fontSize,
                      onFontSizeChanged: _saveFontSize,
                      defaultTab: _defaultTab,
                      onDefaultTabChanged: (tab) {
                        setState(() {
                          _defaultTab = tab;
                        });
                        _saveSettings();
                      },
                    ),
                  ),
                );
              },
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).colorScheme.secondary,
            labelColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.white,
            unselectedLabelColor:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.white70,
            tabs: const [
              Tab(icon: Icon(Icons.text_fields), text: 'Romanized'),
              Tab(icon: Icon(Icons.translate), text: 'தமிழ்'),
              Tab(icon: Icon(Icons.collections_bookmark), text: 'Library'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    // Swipe right
                    if (_tabController.index > 0) {
                      _tabController.animateTo(_tabController.index - 1);
                    }
                  } else if (details.primaryVelocity! < 0) {
                    // Swipe left
                    if (_tabController.index < 2) {
                      _tabController.animateTo(_tabController.index + 1);
                    }
                  }
                },
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLanguageView(isTamil: false),
                    _buildLanguageView(isTamil: true),
                    _buildLibraryView(),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _tabController.index < 2 && books.isNotEmpty
            ? _buildBottomBar(
                books.cast<Map<String, dynamic>>(),
                availableChapters,
                bottomBarColor,
              )
            : null,
        floatingActionButton: _tabController.index == 2
            ? null
            : FloatingActionButton(
                onPressed: _isAudioPlaying ? _stopAudio : _toggleTheme,
                backgroundColor: _isAudioPlaying
                    ? Colors.red
                    : Theme.of(context).primaryColor,
                shape: const CircleBorder(),
                tooltip: _isAudioPlaying
                    ? 'Stop audio'
                    : (appThemeMode.value == ThemeMode.light
                        ? 'Switch to dark mode'
                        : 'Switch to light mode'),
                child: Icon(
                  _isAudioPlaying
                      ? Icons.stop
                      : (appThemeMode.value == ThemeMode.light
                          ? Icons.dark_mode
                          : Icons.light_mode),
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

// ====================================================================
// 4. PROFESSIONAL ADD NOTE SCREEN WIDGET
// ====================================================================
class AddNoteScreen extends StatefulWidget {
  final Map<String, dynamic>? existingNote;
  final Function(Map<String, dynamic>) onNoteSaved;
  final VoidCallback? onNoteDeleted;

  const AddNoteScreen({
    super.key,
    this.existingNote,
    required this.onNoteSaved,
    this.onNoteDeleted,
  });

  @override
  AddNoteScreenState createState() => AddNoteScreenState();
}

class AddNoteScreenState extends State<AddNoteScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  bool _hasUnsavedChanges = false;
  String _selectedCategory = 'Personal';
  final List<String> _categories = [
    'Personal',
    'Study',
    'Prayer',
    'Sermon',
    'Reflection'
  ];

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existingNote?['title'] ?? '');
    _contentController =
        TextEditingController(text: widget.existingNote?['content'] ?? '');
    _selectedCategory = widget.existingNote?['category'] ?? 'Personal';

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
    _autoUpdate();
  }

  void _autoUpdate() {
    if (_titleController.text.trim().isNotEmpty &&
        widget.existingNote != null) {
      final note = {
        'id': widget.existingNote!['id'],
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category': _selectedCategory,
        'createdAt': widget.existingNote!['createdAt'],
        'updatedAt': DateTime.now().toIso8601String(),
      };

      widget.onNoteSaved(note);
      setState(() {
        _hasUnsavedChanges = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content:
            const Text('You have unsaved changes. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      _saveNoteAndExit();
      return true;
    }
    return result == 'discard';
  }

  void _saveNote() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for your note')),
      );
      _titleFocusNode.requestFocus();
      return;
    }

    final note = {
      'id': widget.existingNote?['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'category': _selectedCategory,
      'createdAt':
          widget.existingNote?['createdAt'] ?? DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    widget.onNoteSaved(note);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.existingNote != null
            ? 'Note updated successfully'
            : 'Note saved successfully'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _saveNoteAndExit() {
    if (_titleController.text.trim().isEmpty) {
      return;
    }

    final note = {
      'id': widget.existingNote?['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'category': _selectedCategory,
      'createdAt':
          widget.existingNote?['createdAt'] ?? DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    widget.onNoteSaved(note);
  }

  void _deleteNote() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
            'Are you sure you want to delete this note? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onNoteDeleted?.call();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Note deleted successfully'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _insertTemplate() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insert Template',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Bible Study Template'),
              onTap: () {
                Navigator.pop(context);
                _contentController.text +=
                    '\n\nPassage: \nKey Verse: \nMain Theme: \nPersonal Application: \nPrayer Points: ';
                _onTextChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('Prayer Request Template'),
              onTap: () {
                Navigator.pop(context);
                _contentController.text +=
                    '\n\nPrayer Request: \nScripture Reference: \nDate: ${DateTime.now().toString().split(' ')[0]}\nUpdate: ';
                _onTextChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb),
              title: const Text('Sermon Notes Template'),
              onTap: () {
                Navigator.pop(context);
                _contentController.text +=
                    '\n\nSpeaker: \nTopic: \nScripture: \nKey Points:\n1. \n2. \n3. \nAction Items: ';
                _onTextChanged();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (!didPop && _hasUnsavedChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existingNote != null ? 'Edit Note' : 'Add Note'),
          actions: [
            if (widget.existingNote != null)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteNote,
                tooltip: 'Delete Note',
              ),
            IconButton(
              icon: const Icon(Icons.insert_drive_file),
              onPressed: _insertTemplate,
              tooltip: 'Insert Template',
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveNote,
              tooltip: 'Save Note',
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter note title...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      prefixIcon: const Icon(Icons.title),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Row(
                              children: [
                                Icon(
                                  _getCategoryIcon(category),
                                  size: 20,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white70
                                      : Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(category),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                          _autoUpdate();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
                child: TextField(
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Start writing your note here...\n\nTip: Use the template button above to insert common note formats.',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.existingNote != null
                      ? 'Last updated: ${_formatDate(widget.existingNote!['updatedAt'] ?? widget.existingNote!['createdAt'])}'
                      : 'Tap save to create your note',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Personal':
        return Icons.person;
      case 'Study':
        return Icons.school;
      case 'Prayer':
        return Icons.favorite;
      case 'Sermon':
        return Icons.mic;
      case 'Reflection':
        return Icons.lightbulb;
      default:
        return Icons.note;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes} min ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}

// ====================================================================
// 5. SETTINGS SCREEN WIDGET
// ====================================================================
class SettingsScreen extends StatefulWidget {
  final double fontSize;
  final Function(double) onFontSizeChanged;
  final int defaultTab;
  final Function(int) onDefaultTabChanged;

  const SettingsScreen({
    super.key,
    required this.fontSize,
    required this.onFontSizeChanged,
    required this.defaultTab,
    required this.onDefaultTabChanged,
  });

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  late double _currentFontSize;
  late int _currentDefaultTab;
  final String _appVersion = '1.0.1';
  final List<String> _tabNames = ['Romanized', 'Tamil', 'Library'];

  @override
  void initState() {
    super.initState();
    _currentFontSize = widget.fontSize;
    _currentDefaultTab = widget.defaultTab;
  }

  void _showAppInfo() {
    showAboutDialog(
      context: context,
      applicationName: 'JCG BIBLE',
      applicationVersion: _appVersion,
      applicationIcon: Icon(
        Icons.menu_book,
        color: Theme.of(context).primaryColor,
      ),
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.1),
                Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                'This app is Dedicated to',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Pastor Daniel Clinton',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'This app provides the Bible text in Tamil and its Romanized equivalent for easy reading and reference.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'Developer: Suresh Edison',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Data Source: Loaded from assets/bible_data.json.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Icon(
                Icons.format_size,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Theme.of(context).primaryColor,
              ),
              title: const Text('Font Size'),
              subtitle: Text('${_currentFontSize.toInt()}'),
              trailing: SizedBox(
                width: 150,
                child: Slider(
                  value: _currentFontSize,
                  min: 12.0,
                  max: 24.0,
                  divisions: 6,
                  label: _currentFontSize.toInt().toString(),
                  onChanged: (value) {
                    setState(() {
                      _currentFontSize = value;
                    });
                    widget.onFontSizeChanged(value);
                  },
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.language,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Theme.of(context).primaryColor,
              ),
              title: const Text('Default Language'),
              subtitle: Text(_tabNames[_currentDefaultTab]),
              trailing: DropdownButton<int>(
                value: _currentDefaultTab,
                items: List.generate(3, (index) {
                  return DropdownMenuItem(
                    value: index,
                    child: Text(_tabNames[index]),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _currentDefaultTab = value;
                    });
                    widget.onDefaultTabChanged(value);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Default tab set to ${_tabNames[value]}',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.info_outline,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Theme.of(context).primaryColor,
              ),
              title: const Text('App Info'),
              subtitle: Text('Version: $_appVersion'),
              onTap: _showAppInfo,
            ),
          ),
        ],
      ),
    );
  }
}
