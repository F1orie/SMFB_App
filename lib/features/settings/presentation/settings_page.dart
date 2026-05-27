import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smf_app/features/alarm/infrastructure/sleep_repository.dart';

// SharedPreferences キー
const _kAlarmVolume = 'alarm_volume';
const _kSnoozeMinutes = 'snooze_minutes';
const _kSensorNormFactor = 'sensor_norm_factor';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ── アラーム設定 ────────────────────────────────────────────
  double _alarmVolume = 0.8; // 0.0〜1.0
  int _snoozeMinutes = 5; // 5 / 10 / 15

  // ── センサー設定 ────────────────────────────────────────────
  // スライダー値: 0=低め(3.0) / 1=標準(2.0) / 2=高め(1.0)
  int _sensitivityStep = 1;

  // ── バージョン ──────────────────────────────────────────────
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadPackageInfo();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _alarmVolume = prefs.getDouble(_kAlarmVolume) ?? 0.8;
      _snoozeMinutes = prefs.getInt(_kSnoozeMinutes) ?? 5;
      final normFactor = prefs.getDouble(_kSensorNormFactor) ?? 2.0;
      _sensitivityStep = _normFactorToStep(normFactor);
    });
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  // normFactor → スライダーステップ変換（3.0=0, 2.0=1, 1.0=2）
  int _normFactorToStep(double factor) {
    if (factor >= 2.5) return 0; // 低め
    if (factor >= 1.5) return 1; // 標準
    return 2; // 高め
  }

  double _stepToNormFactor(int step) {
    switch (step) {
      case 0:
        return 3.0;
      case 2:
        return 1.0;
      default:
        return 2.0;
    }
  }

  Future<void> _saveAlarmVolume(double value) async {
    setState(() => _alarmVolume = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kAlarmVolume, value);
  }

  Future<void> _saveSnoozeMinutes(int value) async {
    setState(() => _snoozeMinutes = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSnoozeMinutes, value);
  }

  Future<void> _saveSensitivity(int step) async {
    setState(() => _sensitivityStep = step);
    final factor = _stepToNormFactor(step);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kSensorNormFactor, factor);
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('すべての記録を削除しますか？'),
        content: const Text(
          'これまでの睡眠データがすべて削除されます。\nこの操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await SleepRepository.instance.clearAll();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('すべての記録を削除しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          // ── アラーム ──────────────────────────────────────────
          _SectionHeader(title: 'アラーム'),
          _SettingsTile(
            label: 'アラーム音量',
            trailing: Text(
              '${(_alarmVolume * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Slider(
              value: _alarmVolume,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: _saveAlarmVolume,
            ),
          ),
          _SettingsTile(
            label: 'スヌーズ時間',
            trailing: DropdownButton<int>(
              value: _snoozeMinutes,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 5, child: Text('5分')),
                DropdownMenuItem(value: 10, child: Text('10分')),
                DropdownMenuItem(value: 15, child: Text('15分')),
              ],
              onChanged: (v) {
                if (v != null) _saveSnoozeMinutes(v);
              },
            ),
          ),

          // ── センサー ──────────────────────────────────────────
          _SectionHeader(title: 'センサー'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('センサー感度'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                const Text('低め', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Expanded(
                  child: Slider(
                    value: _sensitivityStep.toDouble(),
                    min: 0,
                    max: 2,
                    divisions: 2,
                    onChanged: (v) => _saveSensitivity(v.round()),
                  ),
                ),
                const Text('高め', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Center(
              child: Text(
                _sensitivityStep == 0
                    ? '低め（鈍感）'
                    : _sensitivityStep == 2
                        ? '高め（敏感）'
                        : '標準',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ),
          ),

          // ── 一般 ──────────────────────────────────────────────
          _SectionHeader(title: '一般'),
          ListTile(
            title: const Text('すべての記録を削除'),
            trailing: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _confirmDeleteAll,
              child: const Text('削除'),
            ),
          ),
          _SettingsTile(
            label: 'バージョン',
            trailing: Text(
              _version.isEmpty
                  ? '---'
                  : '$_version ($_buildNumber)',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── 補助ウィジェット ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.label, required this.trailing});
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: trailing,
    );
  }
}
