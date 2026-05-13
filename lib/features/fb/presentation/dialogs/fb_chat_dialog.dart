// lib/features/fb/presentation/dialogs/fb_chat_dialog.dart
import 'package:flutter/material.dart';

class FbChatDialog extends StatelessWidget {
  const FbChatDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("AI分析チャット", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Expanded(
            child: Center(child: Text("ここにチャットのやり取りが表示されます")),
          ),
          TextField(
            decoration: InputDecoration(
              hintText: "「もっと深く寝るには？」",
              suffixIcon: IconButton(onPressed: () {}, icon: const Icon(Icons.send)),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}