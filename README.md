git上にあるもの
├── analysis_config.dart.example  ← テンプレート（キーなし）
└── .gitignore                    ← analysis_config.dart を除外

各自のローカルにだけあるもの
└── analysis_config.dart          ← 実際のキーが入っている

クローンしたときは1回だけこれをやるだけ：
bashcp lib/features/fb/application/config/analysis_config.dart.example \
   lib/features/fb/application/config/analysis_config.dart
   #ファイルを開いてAPIキーを貼り付ける
