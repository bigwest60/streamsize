import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:streamsize_core/streamsize_core.dart';
import 'package:streamsize_platform_discovery/streamsize_platform_discovery.dart';
import 'services/speed_test_service.dart';
import 'widgets/add_device_modal.dart';

void main() {
  runApp(const StreamsizeApp());
}

class StreamsizeApp extends StatelessWidget {
  const StreamsizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE07A5F),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F2EB),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Streamsize',
      theme: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(bodyColor: const Color(0xFF2D2433)),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const RecommendationFlowPage(),
    );
  }
}

class RecommendationFlowPage extends StatefulWidget {
  const RecommendationFlowPage({super.key, this.discovery});

  /// Injectable discovery service — leave null for production (uses MDNSDiscoveryService).
  final DiscoveryService? discovery;

  @override
  State<RecommendationFlowPage> createState() => _RecommendationFlowPageState();
}

class _RecommendationFlowPageState extends State<RecommendationFlowPage> {
  final _engine = RecommendationEngine();
  final _speedTest = SpeedTestService();
  late final DiscoveryService _discovery;
  late HouseholdScenario _scenario;
  List<DetectedDevice> _devices = [];
  final List<DetectedDevice> _manualDevices = [];
  bool _isScanning = true;
  bool _isSpeedTesting = false;
  double? _measuredDownloadMbps;
  double? _measuredUploadMbps;
  int _stepIndex = 0;

  List<DetectedDevice> get _allDevices {
    // Deduplicate: skip manual devices whose display name already appears in scan results.
    final scannedNames =
        _devices.map((d) => d.displayName.toLowerCase().trim()).toSet();
    final uniqueManual = _manualDevices.where(
      (m) => !scannedNames.contains(m.displayName.toLowerCase().trim()),
    );
    return [..._devices, ...uniqueManual];
  }

  @override
  void initState() {
    super.initState();
    _discovery = widget.discovery ?? MDNSDiscoveryService();
    _scenario = HouseholdScenario(
      homeProfile: HomeProfile.medium,
      devices: const [],
      simultaneous4kStreams: 2,
      simultaneousHdStreams: 2,
      simultaneousVideoCalls: 1,
      remoteWorkers: 1,
      onlineGamers: 1,
      cloudBackupEnabled: true,
      securityCameraCount: 2,
      largeDownloadHabit: LargeDownloadHabit.weekly,
    );
    _discoverDevices();
  }

  Future<void> _discoverDevices() async {
    debugPrint('[main.dart] _discoverDevices called');
    final devices = await _discovery.discoverVisibleDevices();
    debugPrint('[main.dart] discovered ${devices.length} devices');
    if (!mounted) return;
    setState(() {
      _devices = List<DetectedDevice>.from(devices);
      _isScanning = false;
      _scenario = _scenario.copyWith(devices: _allDevices);
    });
  }

  void _onCategoryChanged(DetectedDevice device, DeviceCategory category) {
    setState(() {
      final di = _devices.indexWhere((d) => d.displayName == device.displayName);
      if (di >= 0) {
        _devices[di] = device.copyWith(category: category);
      } else {
        final mi = _manualDevices.indexWhere(
            (d) => d.displayName == device.displayName);
        if (mi >= 0) _manualDevices[mi] = device.copyWith(category: category);
      }
      _scenario = _scenario.copyWith(devices: _allDevices);
    });
  }

  Future<void> _addDeviceManually() async {
    final device = await showAddDeviceModal(context);
    if (device == null || !mounted) return;
    setState(() {
      _manualDevices.add(device);
      _scenario = _scenario.copyWith(devices: _allDevices);
    });
  }

  Future<void> _runSpeedTest() async {
    if (_isSpeedTesting) return;
    setState(() => _isSpeedTesting = true);
    final results = await Future.wait([
      _speedTest.measureDownload(),
      _speedTest.measureUpload(),
    ]);
    if (!mounted) return;
    setState(() {
      _measuredDownloadMbps = results[0];
      _measuredUploadMbps = results[1];
      _isSpeedTesting = false;
    });
  }

  void _shareResults(PlanRecommendation recommendation) {
    final text =
        'My home needs a ${recommendation.downloadMbps}/${recommendation.uploadMbps} Mbps internet plan.\n'
        '${_allDevices.length} devices detected. ${recommendation.confidence.name} confidence.\n'
        'Generated by Streamsize — https://github.com/bigwest60/streamsize';
    Share.share(text).catchError((Object _) {
      Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Result copied to clipboard')),
        );
      }
      return ShareResult('', ShareResultStatus.dismissed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final recommendation = _engine.buildRecommendation(_scenario);
    final steps = [
      _WelcomeStep(recommendation: recommendation, isScanning: _isScanning),
      _DevicesStep(
        devices: _allDevices,
        isScanning: _isScanning,
        onCategoryChanged: _onCategoryChanged,
        onAddDeviceManually: _addDeviceManually,
      ),
      _UsageStep(
        scenario: _scenario,
        onHomeProfileChanged: (value) => setState(() {
          _scenario = _scenario.copyWith(homeProfile: value);
        }),
        onStreams4kChanged: (value) => setState(() {
          _scenario = _scenario.copyWith(simultaneous4kStreams: value);
        }),
        onStreamsHdChanged: (value) => setState(() {
          _scenario = _scenario.copyWith(simultaneousHdStreams: value);
        }),
        onVideoCallsChanged: (value) => setState(() {
          _scenario = _scenario.copyWith(simultaneousVideoCalls: value);
        }),
        onRemoteWorkersChanged: (value) => setState(() {
          _scenario = _scenario.copyWith(remoteWorkers: value);
        }),
        onOnlineGamersChanged: (value) => setState(() {
          _scenario = _scenario.copyWith(onlineGamers: value);
        }),
        onSecurityCamerasChanged: (value) => setState(() {
          _scenario = _scenario.copyWith(securityCameraCount: value);
        }),
        onDownloadHabitChanged: (value) => setState(() {
          _scenario = _scenario.copyWith(largeDownloadHabit: value);
        }),
        onCloudBackupChanged: (value) => setState(() {
          _scenario = _scenario.copyWith(cloudBackupEnabled: value);
        }),
      ),
      _ResultsStep(
        recommendation: recommendation,
        scenario: _scenario,
        isSpeedTesting: _isSpeedTesting,
        measuredDownloadMbps: _measuredDownloadMbps,
        measuredUploadMbps: _measuredUploadMbps,
        onRunSpeedTest: _runSpeedTest,
        onShare: () => _shareResults(recommendation),
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -120,
            left: -20,
            child: _AmbientGlow(color: Color(0xFFF6C9A9), size: 280),
          ),
          const Positioned(
            right: -90,
            bottom: -40,
            child: _AmbientGlow(color: Color(0xFFE0D3FF), size: 260),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 980;
                      return wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: SingleChildScrollView(
                                    child: _IntroPanel(
                                      stepIndex: _stepIndex,
                                      recommendation: recommendation,
                                      deviceCount: _devices.length,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  flex: 5,
                                  child: SingleChildScrollView(
                                    child: _FlowCard(
                                      stepIndex: _stepIndex,
                                      onBack: _stepIndex == 0
                                          ? null
                                          : () => setState(() {
                                                _stepIndex -= 1;
                                              }),
                                      onNext: _stepIndex == steps.length - 1 || _isScanning
                                          ? null
                                          : () => setState(() {
                                                _stepIndex += 1;
                                              }),
                                      child: steps[_stepIndex],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              children: [
                                _IntroPanel(
                                  stepIndex: _stepIndex,
                                  recommendation: recommendation,
                                  deviceCount: _allDevices.length,
                                ),
                                const SizedBox(height: 20),
                                _FlowCard(
                                  stepIndex: _stepIndex,
                                  onBack: _stepIndex == 0
                                      ? null
                                      : () => setState(() {
                                            _stepIndex -= 1;
                                          }),
                                  onNext: _stepIndex == steps.length - 1 || _isScanning
                                      ? null
                                      : () => setState(() {
                                            _stepIndex += 1;
                                          }),
                                  child: steps[_stepIndex],
                                ),
                              ],
                            );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel({
    required this.stepIndex,
    required this.recommendation,
    required this.deviceCount,
  });

  final int stepIndex;
  final PlanRecommendation recommendation;
  final int deviceCount;

  static const _stepTitles = [
    'Welcome',
    'Check devices',
    'Peak usage',
    'Recommendation',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3D7BC), Color(0xFFF9EAD8), Color(0xFFF7F2EB)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('Streamsize guide'),
          ),
          const SizedBox(height: 26),
          Text(
            'Find the plan your home actually needs.',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A calmer way to choose home internet: check a few visible devices, describe the busiest moments, and get a recommendation you can trust.',
            style: theme.textTheme.titleMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What we already know', style: theme.textTheme.titleMedium),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Visible devices',
                        value: '$deviceCount',
                        icon: Icons.devices_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        label: 'Current estimate',
                        value: '${recommendation.downloadMbps} Mbps',
                        icon: Icons.speed_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          ...List.generate(
            _stepTitles.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: index <= stepIndex ? const Color(0xFF7C5CFC) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: index <= stepIndex ? Colors.white : const Color(0xFF7B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(_stepTitles[index], style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF2D1E2F),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A gentle nudge',
                  style: TextStyle(color: Color(0xFFEBDCF4)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Most households with your profile do not need gigabit.',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We will show you what is truly necessary and what is just sales pressure.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFEBDCF4),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({
    required this.stepIndex,
    required this.child,
    this.onBack,
    this.onNext,
  });

  final int stepIndex;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final isLast = stepIndex == 3;
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressHeader(stepIndex: stepIndex),
          const SizedBox(height: 28),
          child,
          const SizedBox(height: 28),
          Row(
            children: [
              if (onBack != null)
                OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('Back'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(isLast ? 'Done' : 'Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.recommendation, required this.isScanning});

  final PlanRecommendation recommendation;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('A simpler way to size your internet', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(
          'We combine visible devices with a few easy questions about peak-time habits, then recommend a plan that feels fast without overbuying.',
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: const [
            _FeatureChip(label: 'Quick device check'),
            _FeatureChip(label: 'Peak usage questions'),
            _FeatureChip(label: 'Plain-English results'),
          ],
        ),
        if (isScanning) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text('Scanning your network...', style: theme.textTheme.bodyMedium),
            ],
          ),
        ],
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF7F0), Color(0xFFF5EDE4)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xFFE07A5F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You are already close to an answer', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Right now, your sample household is tracking toward ${recommendation.planLabel}. We will refine that over the next few screens.',
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DevicesStep extends StatelessWidget {
  const _DevicesStep({
    required this.devices,
    required this.isScanning,
    required this.onCategoryChanged,
    required this.onAddDeviceManually,
  });

  final List<DetectedDevice> devices;
  final bool isScanning;
  final void Function(DetectedDevice device, DeviceCategory category) onCategoryChanged;
  final VoidCallback onAddDeviceManually;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highConfidence = devices.where((device) => device.confidence == ConfidenceScore.high).length;
    final wiredCount = devices.where((device) => device.connection == ConnectionType.ethernet).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review your home scan', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(
          'We found a few likely devices on the network and grouped them by what they appear to be. You can fine-tune anything that looks off before we make the recommendation.',
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 24),
        if (devices.isEmpty && !isScanning) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7F0),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFF0E3D8)),
            ),
            child: Column(
              children: [
                const Icon(Icons.wifi_find_rounded, size: 40, color: Color(0xFFE07A5F)),
                const SizedBox(height: 12),
                Text('No devices detected', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'The scan finished but found nothing. This happens on some routers with mDNS isolation. Add your devices manually below — the recommendation will still be accurate.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF7F0), Color(0xFFF5E9DC)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scan confidence looks good', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '$highConfidence of ${devices.length} devices were recognized with high confidence, and $wiredCount appear to be on Ethernet.',
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Devices found',
                        value: '${devices.length}',
                        icon: Icons.router_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        label: 'High confidence',
                        value: '$highConfidence',
                        icon: Icons.verified_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _FeatureChip(label: 'Grouped by device type'),
              _FeatureChip(label: 'Connection hints included'),
              _FeatureChip(label: 'Editable before scoring'),
            ],
          ),
          const SizedBox(height: 24),
          ...devices.map(
            (device) => _DeviceInsightCard(
              device: device,
              onCategoryChanged: (category) => onCategoryChanged(device, category),
            ),
          ),
        ],
        // "Add manually" text link — macOS-native feel; FABs are mobile-native.
        TextButton.icon(
          onPressed: onAddDeviceManually,
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: const Text('Add a device manually'),
        ),
      ],
    );
  }
}

class _UsageStep extends StatelessWidget {
  const _UsageStep({
    required this.scenario,
    required this.onHomeProfileChanged,
    required this.onStreams4kChanged,
    required this.onStreamsHdChanged,
    required this.onVideoCallsChanged,
    required this.onRemoteWorkersChanged,
    required this.onOnlineGamersChanged,
    required this.onSecurityCamerasChanged,
    required this.onDownloadHabitChanged,
    required this.onCloudBackupChanged,
  });

  final HouseholdScenario scenario;
  final ValueChanged<HomeProfile> onHomeProfileChanged;
  final ValueChanged<int> onStreams4kChanged;
  final ValueChanged<int> onStreamsHdChanged;
  final ValueChanged<int> onVideoCallsChanged;
  final ValueChanged<int> onRemoteWorkersChanged;
  final ValueChanged<int> onOnlineGamersChanged;
  final ValueChanged<int> onSecurityCamerasChanged;
  final ValueChanged<LargeDownloadHabit> onDownloadHabitChanged;
  final ValueChanged<bool> onCloudBackupChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How busy does your home get?', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(
          'Tell us what tends to happen at the same time. Peak moments matter more than device count alone.',
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 24),
        _SpotlightCard(
          title: 'Home rhythm',
          subtitle: 'This helps us set a sensible baseline before we look at streaming, work, and upload-heavy habits.',
          child: DropdownButtonFormField<HomeProfile>(
            initialValue: scenario.homeProfile,
            decoration: const InputDecoration(labelText: 'Home size'),
            items: HomeProfile.values
                .map(
                  (profile) => DropdownMenuItem(
                    value: profile,
                    child: Text(profile.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onHomeProfileChanged(value);
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        _QuestionCounter(
          label: '4K streams at the same time',
          helper: 'Think Netflix, Apple TV+, or sports in ultra HD.',
          value: scenario.simultaneous4kStreams,
          onChanged: onStreams4kChanged,
        ),
        _QuestionCounter(
          label: 'HD streams at the same time',
          helper: 'For TVs or tablets that are not usually streaming in 4K.',
          value: scenario.simultaneousHdStreams,
          onChanged: onStreamsHdChanged,
        ),
        _QuestionCounter(
          label: 'Live video calls',
          helper: 'Zoom, FaceTime, Teams, and similar apps.',
          value: scenario.simultaneousVideoCalls,
          onChanged: onVideoCallsChanged,
        ),
        _QuestionCounter(
          label: 'People working from home',
          helper: 'Includes work calls, cloud apps, and large file sync.',
          value: scenario.remoteWorkers,
          onChanged: onRemoteWorkersChanged,
        ),
        _QuestionCounter(
          label: 'Online gamers',
          helper: 'Gaming does not use huge bandwidth, but it benefits from headroom.',
          value: scenario.onlineGamers,
          onChanged: onOnlineGamersChanged,
        ),
        _QuestionCounter(
          label: 'Security cameras uploading video',
          helper: 'Cameras affect upload more than download.',
          value: scenario.securityCameraCount,
          onChanged: onSecurityCamerasChanged,
        ),
        const SizedBox(height: 12),
        _SpotlightCard(
          title: 'Extra headroom',
          subtitle: 'These are the habits that often make households feel slower than expected even when browsing is fine.',
          child: Column(
            children: [
              DropdownButtonFormField<LargeDownloadHabit>(
                initialValue: scenario.largeDownloadHabit,
                decoration: const InputDecoration(labelText: 'How often do you download big files?'),
                items: LargeDownloadHabit.values
                    .map(
                      (habit) => DropdownMenuItem(
                        value: habit,
                        child: Text(habit.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onDownloadHabitChanged(value);
                  }
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cloud backup or always-on sync'),
                subtitle: const Text('Turn this on for photo backup, NAS sync, or creator-style upload workflows.'),
                value: scenario.cloudBackupEnabled,
                onChanged: onCloudBackupChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultsStep extends StatelessWidget {
  const _ResultsStep({
    required this.recommendation,
    required this.scenario,
    required this.isSpeedTesting,
    required this.onRunSpeedTest,
    required this.onShare,
    this.measuredDownloadMbps,
    this.measuredUploadMbps,
  });

  final PlanRecommendation recommendation;
  final HouseholdScenario scenario;
  final bool isSpeedTesting;
  final double? measuredDownloadMbps;
  final double? measuredUploadMbps;
  final VoidCallback onRunSpeedTest;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shouldSkipGigabit = recommendation.downloadMbps < 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Your right-sized plan', style: theme.textTheme.headlineSmall),
            ),
            _RecommendationConfidenceBadge(confidence: recommendation.confidence),
          ],
        ),
        if (recommendation.confidence == ConfidenceScore.low) ...[
          const SizedBox(height: 8),
          Text(
            'No devices detected — the estimate is based on your usage answers only. Go back and add devices manually for a more accurate result.',
            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFC26A5A), height: 1.4),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Based on the devices we saw and the busiest moments you described, here is the plan we would recommend.',
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2D1E2F), Color(0xFF4A3150)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 24,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  shouldSkipGigabit ? 'You probably do not need gigabit' : 'Heavy-usage household',
                  style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${recommendation.downloadMbps}',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Mbps',
                      style: theme.textTheme.headlineSmall?.copyWith(color: const Color(0xFFEBDCF4)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Recommended plan: ${recommendation.planLabel}',
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                shouldSkipGigabit
                    ? 'This should comfortably cover ${scenario.simultaneous4kStreams} 4K streams, ${scenario.simultaneousVideoCalls} live calls, and everyday browsing without paying for a premium tier you are unlikely to feel.'
                    : 'Your peak-time habits suggest a faster tier is justified so the busiest moments still feel smooth.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFEBDCF4),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _DarkStatPill(label: 'Upload ${recommendation.uploadMbps} Mbps'),
                  _DarkStatPill(label: 'Confidence ${recommendation.confidence.name}'),
                  _DarkStatPill(label: '${scenario.devices.length} devices considered'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Speed test section
        _SpotlightCard(
          title: 'Compare with your actual speed',
          subtitle: 'Optional: run a quick test to see how your current plan compares to our recommendation.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (measuredDownloadMbps != null || measuredUploadMbps != null) ...[
                _SpeedComparisonRow(
                  label: 'Download',
                  recommended: recommendation.downloadMbps.toDouble(),
                  measured: measuredDownloadMbps,
                ),
                const SizedBox(height: 8),
                _SpeedComparisonRow(
                  label: 'Upload',
                  recommended: recommendation.uploadMbps.toDouble(),
                  measured: measuredUploadMbps,
                ),
                const SizedBox(height: 12),
              ],
              TextButton.icon(
                onPressed: isSpeedTesting ? null : onRunSpeedTest,
                icon: isSpeedTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.speed_rounded, size: 18),
                label: Text(isSpeedTesting ? 'Testing...' : 'Test actual speed'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Share button
        OutlinedButton.icon(
          onPressed: onShare,
          icon: const Icon(Icons.share_rounded, size: 18),
          label: const Text('Share this result'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _ResultNarrativeCard(
                title: 'Why this plan should feel right',
                icon: Icons.favorite_border_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: recommendation.reasons
                      .map(
                        (reason) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(Icons.check_circle, size: 18, color: Color(0xFFE07A5F)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(reason, style: theme.textTheme.bodyLarge)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ResultNarrativeCard(
                title: 'What you are not paying for',
                icon: Icons.savings_outlined,
                child: Text(
                  shouldSkipGigabit
                      ? 'Good news: this result suggests your home probably does not need a top-tier gigabit plan unless your usage grows or you want extra upload headroom.'
                      : 'A faster tier looks justified here, but the recommendation is still sized to your real usage rather than the biggest plan on the price sheet.',
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecommendationConfidenceBadge extends StatelessWidget {
  const _RecommendationConfidenceBadge({required this.confidence});

  final ConfidenceScore confidence;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (confidence) {
      ConfidenceScore.high => ('High confidence', const Color(0xFF3FA56A)),
      ConfidenceScore.medium => ('Good estimate', const Color(0xFF4A90D9)),
      ConfidenceScore.low => ('Rough estimate', const Color(0xFFC26A5A)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SpeedComparisonRow extends StatelessWidget {
  const _SpeedComparisonRow({
    required this.label,
    required this.recommended,
    this.measured,
  });

  final String label;
  final double recommended;
  final double? measured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (measured == null) {
      return Row(
        children: [
          Expanded(child: Text('$label:', style: theme.textTheme.bodyMedium)),
          Text('–', style: theme.textTheme.bodyMedium),
        ],
      );
    }
    final ratio = measured! / recommended;
    final color = ratio >= 0.8
        ? const Color(0xFF3FA56A)
        : ratio >= 0.5
            ? const Color(0xFFE09A3E)
            : const Color(0xFFC26A5A);
    final measuredStr = measured! >= 100
        ? '${measured!.round()} Mbps'
        : '${measured!.toStringAsFixed(1)} Mbps';

    return Row(
      children: [
        Expanded(child: Text('$label:', style: theme.textTheme.bodyMedium)),
        Text(
          '$measuredStr vs ${recommended.round()} Mbps recommended',
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.stepIndex});

  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step ${stepIndex + 1} of 4', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 12),
        Row(
          children: List.generate(
            4,
            (index) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index == 3 ? 0 : 10),
                height: 8,
                decoration: BoxDecoration(
                  color: index <= stepIndex ? const Color(0xFF7C5CFC) : const Color(0xFFEFE4D7),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFE07A5F)),
          const SizedBox(height: 12),
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}


class _DeviceInsightCard extends StatelessWidget {
  const _DeviceInsightCard({
    required this.device,
    required this.onCategoryChanged,
  });

  final DetectedDevice device;
  final ValueChanged<DeviceCategory> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFF0E3D8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CategoryIcon(category: device.category, large: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.displayName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(_deviceNarrative(device), style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                  ],
                ),
              ),
              _ConfidenceBadge(confidence: device.confidence),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniInfoPill(icon: Icons.wifi_rounded, label: device.connection.label),
              _MiniInfoPill(icon: Icons.category_rounded, label: device.category.label),
              _MiniInfoPill(icon: Icons.insights_rounded, label: _confidenceCopy(device.confidence)),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<DeviceCategory>(
            initialValue: device.category,
            decoration: const InputDecoration(labelText: 'Looks more like'),
            items: DeviceCategory.values
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onCategoryChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final ConfidenceScore confidence;

  @override
  Widget build(BuildContext context) {
    final color = switch (confidence) {
      ConfidenceScore.high => const Color(0xFF3FA56A),
      ConfidenceScore.medium => const Color(0xFFE09A3E),
      ConfidenceScore.low => const Color(0xFFC26A5A),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        confidence.name,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  const _MiniInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFE07A5F)),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

String _confidenceCopy(ConfidenceScore confidence) {
  return switch (confidence) {
    ConfidenceScore.high => 'Strong match',
    ConfidenceScore.medium => 'Likely match',
    ConfidenceScore.low => 'Needs review',
  };
}

String _deviceNarrative(DetectedDevice device) {
  final categoryText = switch (device.category) {
    DeviceCategory.tv => 'This looks like a streaming or TV device.',
    DeviceCategory.phone => 'This looks like a phone that joins over Wi-Fi.',
    DeviceCategory.tablet => 'This appears to be a tablet-style device.',
    DeviceCategory.laptop => 'This appears to be a laptop or desktop computer.',
    DeviceCategory.console => 'This resembles a gaming console.',
    DeviceCategory.camera => 'This looks like a camera that may add upload traffic.',
    DeviceCategory.smartHome => 'This appears to be a smart home accessory or speaker.',
    DeviceCategory.nas => 'This appears to be a NAS or network storage device.',
    DeviceCategory.unknown => 'We found something on the network but could not confidently classify it.',
  };
  return '$categoryText ${_confidenceCopy(device.confidence)} based on the scan.';
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E3D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ResultNarrativeCard extends StatelessWidget {
  const _ResultNarrativeCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFF0E3D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFE07A5F)),
              const SizedBox(width: 10),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(label),
    );
  }
}

class _DarkStatPill extends StatelessWidget {
  const _DarkStatPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _QuestionCounter extends StatelessWidget {
  const _QuestionCounter({
    required this.label,
    required this.helper,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String helper;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E3D8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(helper, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _CounterButton(
            icon: Icons.remove_rounded,
            onPressed: value == 0 ? null : () => onChanged(value - 1),
          ),
          SizedBox(
            width: 44,
            child: Center(child: Text('$value', style: theme.textTheme.titleMedium)),
          ),
          _CounterButton(
            icon: Icons.add_rounded,
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF2E6D9) : const Color(0xFFF3E7D8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: disabled ? const Color(0xFFB9A99B) : const Color(0xFF7C5CFC)),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category, this.large = false});

  final DeviceCategory category;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final icon = switch (category) {
      DeviceCategory.tv => Icons.tv_rounded,
      DeviceCategory.phone => Icons.smartphone_rounded,
      DeviceCategory.tablet => Icons.tablet_mac_rounded,
      DeviceCategory.laptop => Icons.laptop_mac_rounded,
      DeviceCategory.console => Icons.sports_esports_rounded,
      DeviceCategory.camera => Icons.videocam_rounded,
      DeviceCategory.smartHome => Icons.lightbulb_outline_rounded,
      DeviceCategory.nas => Icons.storage_rounded,
      DeviceCategory.unknown => Icons.device_unknown_rounded,
    };

    final size = large ? 52.0 : 42.0;
    final radius = large ? 18.0 : 14.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF3E7D8),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: const Color(0xFFE07A5F), size: large ? 26 : 22),
    );
  }
}
