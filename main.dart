import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SafeRideApp());
}

class SafeRideApp extends StatelessWidget {
  const SafeRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFD62828);
    return MaterialApp(
      title: 'SafeRide Alert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: red),
        scaffoldBackgroundColor: const Color(0xFFF8F8FA),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  String _contactName = '';
  String _contactPhone = '';
  bool _detectionEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _contactName = prefs.getString('contactName') ?? '';
      _contactPhone = prefs.getString('contactPhone') ?? '';
      _detectionEnabled = prefs.getBool('detectionEnabled') ?? false;
    });
  }

  Future<void> _saveContact(String name, String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('contactName', name.trim());
    await prefs.setString('contactPhone', phone.trim());
    if (!mounted) return;
    setState(() {
      _contactName = name.trim();
      _contactPhone = phone.trim();
    });
  }

  Future<void> _saveDetection(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('detectionEnabled', enabled);
    if (!mounted) return;
    setState(() => _detectionEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(
        contactName: _contactName,
        contactPhone: _contactPhone,
        detectionEnabled: _detectionEnabled,
      ),
      ContactsTab(
        initialName: _contactName,
        initialPhone: _contactPhone,
        onSave: _saveContact,
      ),
      SettingsTab(
        detectionEnabled: _detectionEnabled,
        onDetectionChanged: _saveDetection,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: Color(0xFFD62828)),
            SizedBox(width: 10),
            Text('SafeRide Alert', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.tune), selectedIcon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.contactName,
    required this.contactPhone,
    required this.detectionEnabled,
  });

  final String contactName;
  final String contactPhone;
  final bool detectionEnabled;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _busy = false;
  String _status = 'Ready when you need help';
  String? _mapLink;
  Timer? _timer;
  int _secondsLeft = 20;
  bool _countdownActive = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<Position> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Turn on Location in your phone settings.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission was not granted.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<void> _prepareSos({bool demoAccident = false}) async {
    if (_busy) return;
    if (widget.contactPhone.trim().isEmpty) {
      setState(() => _status = 'Add an emergency contact in the Contacts tab first.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Getting your current location…';
    });

    try {
      final position = await _getPosition();
      final link = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      final kind = demoAccident ? 'POSSIBLE ACCIDENT ALERT' : 'SOS EMERGENCY ALERT';
      final message = '$kind\\nI may need assistance.\\n'
          'Location: $link\\n'
          'Location accuracy: about ${position.accuracy.round()} metres.\\n'
          'Time: ${DateTime.now().toLocal().toIso8601String()}';

      if (!mounted) return;
      setState(() {
        _mapLink = link;
        _status = 'Location ready. Review the message in your SMS app before sending.';
      });

      final smsUri = Uri(
        scheme: 'sms',
        path: widget.contactPhone.trim(),
        queryParameters: {'body': message},
      );
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        setState(() => _status = 'Could not open SMS. Use the map link below to share manually.');
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Could not prepare alert: ${error.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startDemoCountdown() {
    if (_countdownActive) return;
    setState(() {
      _secondsLeft = 20;
      _countdownActive = true;
      _status = 'DEMO: possible accident detected. Cancel if you are OK.';
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _countdownActive = false;
          _secondsLeft = 0;
          _status = 'Demo countdown ended. Tap “Send test alert” to continue manually.';
        });
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _cancelCountdown() {
    _timer?.cancel();
    setState(() {
      _countdownActive = false;
      _secondsLeft = 20;
      _status = 'Demo alert cancelled. You can still use SOS any time.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasContact = widget.contactPhone.trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFEEEE), Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your safety matters', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('Prepare an SOS message with your current GPS location.'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.sos, color: Color(0xFFD62828), size: 46),
                const SizedBox(height: 10),
                const Text('Need help now?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  hasContact ? 'Alert contact: ${widget.contactName.isEmpty ? widget.contactPhone : widget.contactName}' : 'Add a trusted contact before testing SOS.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 174,
                  height: 174,
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _prepareSos(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD62828),
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                    ),
                    child: _busy
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning_rounded, size: 35),
                              SizedBox(height: 5),
                              Text('SOS', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
                              Text('Prepare alert', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_status)),
                    ],
                  ),
                ),
                if (_mapLink != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(_mapLink!), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Open my location'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.car_crash_outlined, color: Color(0xFFD62828)),
                    SizedBox(width: 8),
                    Expanded(child: Text('Accident detection demo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    Chip(label: Text('DEMO')),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('This button simulates a detection event. It does not monitor your phone sensors or detect real crashes.'),
                const SizedBox(height: 14),
                if (_countdownActive) ...[
                  Center(child: Text('$_secondsLeft seconds', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900))),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _cancelCountdown,
                      child: const Text('I’m OK — cancel demo'),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _startDemoCountdown,
                      icon: const Icon(Icons.sensors),
                      label: const Text('Simulate possible accident'),
                    ),
                  ),
                if (_countdownActive) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        _timer?.cancel();
                        setState(() {
                          _countdownActive = false;
                          _status = 'Demo confirmed. Preparing test alert…';
                        });
                        _prepareSos(demoAccident: true);
                      },
                      child: const Text('Send test alert now'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Prototype only: alerts may fail. Do not rely on this app as your only way to get emergency help.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class ContactsTab extends StatefulWidget {
  const ContactsTab({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.onSave,
  });

  final String initialName;
  final String initialPhone;
  final Future<void> Function(String name, String phone) onSave;

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void didUpdateWidget(covariant ContactsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialName != widget.initialName) {
      _nameController.text = widget.initialName;
    }
    if (oldWidget.initialPhone != widget.initialPhone) {
      _phoneController.text = widget.initialPhone;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid test contact phone number.')),
      );
      return;
    }
    await widget.onSave(_nameController.text, phone);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency contact saved on this device.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Emergency contact', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Use a trusted contact who has agreed to receive test messages. This MVP saves the contact locally on this phone.'),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Contact name', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number with country code', hintText: '+91...', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 18),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save contact'))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({
    super.key,
    required this.detectionEnabled,
    required this.onDetectionChanged,
  });

  final bool detectionEnabled;
  final ValueChanged<bool> onDetectionChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Settings', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Card(
          child: SwitchListTile(
            value: detectionEnabled,
            onChanged: onDetectionChanged,
            title: const Text('Automatic detection (planned)'),
            subtitle: const Text('This switch saves your preference only. Real sensor monitoring is not implemented in this prototype.'),
            secondary: const Icon(Icons.sensors),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacy & safety', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text('Location is requested when you press SOS. This starter stores your selected contact locally. Do not add real personal data to a public demo build.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
