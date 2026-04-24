##主要操作
git clone <URL>          # リポジトリを取得
git status               # 状態確認
git add .                # 変更をステージング
git commit -m "message"  # コミット
git push                 # リモートに反映
git pull                 # 最新を取得＋マージ

##ブランチ関連
git branch               # ブランチ一覧
git branch -a            # リモート含め一覧
git branch <name>        # ブランチ作成
git checkout <name>      # ブランチ切替
git checkout -b <name>   # 作成＋切替
git switch <name>        # （新しい書き方）切替
git switch -c <name>     # 作成＋切替
git branch -d <name>     # ブランチ削除

##マージ
git merge main           # mainを現在ブランチに統合
git rebase main          # 履歴を付け替え

##変更の取り消し・修正
git restore <file>       # ファイル変更を戻す
git reset HEAD <file>    # add取り消し
git reset --hard HEAD    # 全変更破棄（危険）
git commit --amend       # 直前コミット修正

#履歴の確認
git log                  # コミット履歴
git log --oneline        # 簡潔表示
git diff                 # 差分確認
git show                 # 直近コミット詳細

##サンプルフロー
# 最新を取得
git checkout main
git pull

# 作業ブランチへ
git checkout feature/a

# 最新を取り込む
git merge main

# 作業
git add .
git commit -m "作業内容"
git push