import 'package:flutter/material.dart';
import '../../infrastructure/api/sleep_mock_data.dart';
import '../dialogs/fb_chat_dialog.dart';

class FbDashboardPage extends StatelessWidget {
  const FbDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 起動時に自動でダミーデータを取得
    final sleepData = buildMockDailySleepDepth();

    return Scaffold(
      appBar: AppBar(
        title: const Text("分析フィードバック"),
      ),
      body: SingleChildScrollView( // 内容が増えてもスクロールできるように
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "昨夜の睡眠分析",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // 1. 睡眠の基本情報のカード
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today, color: Colors.blue),
                      title: Text(sleepData.rangeLabel),
                      subtitle: Text("睡眠時間: ${sleepData.summary.sleepDurationLabel}"),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem("効率", sleepData.summary.efficiencyLabel),
                        _buildStatItem("深い睡眠", sleepData.summary.deepTimeLabel),
                        _buildStatItem("中途覚醒", sleepData.summary.awakeningCountLabel),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // 2. AIからのアドバイス・状況説明セクション（ここが重要！）
            const Text(
              "AIアドバイス",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text("状況分析", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ダミーデータ内のメモを表示
                  Text(
                    sleepData.memo,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "改善案:",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const Text(
                    "・就寝2時間前のカフェイン摂取を控えると、中途覚醒が減少する可能性があります。\n・室温を1度下げてみると、深い睡眠の割合が増えるかもしれません。",
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 3. もっと詳しく知りたい人向けのチャットボタン
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => const FbChatDialog(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.chat),
                label: const Text("この結果についてAIに質問する"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 統計用の小項目を作るヘルパーメソッド
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}