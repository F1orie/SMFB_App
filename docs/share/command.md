# Git コマンド

## ■ 基本操作

git clone <URL>          # リポジトリを取得
git status               # 状態確認
git add .                # 変更をステージング
git commit -m "message"  # コミット
git push                 # リモートに反映
git pull                 # 最新を取得＋マージ

---

## ■ ブランチ関連

git branch               # ローカルブランチ一覧
git branch -a            # リモート含め一覧
git branch <name>        # ブランチ作成
git switch <name>        # ブランチ切替（推奨）
git switch -c <name>     # 作成＋切替
git checkout <name>      # 切替（旧）
git checkout -b <name>   # 作成＋切替（旧）
git branch -d <name>     # ブランチ削除

---

## ■ マージ・統合

git merge develop        # developを現在ブランチに統合
git rebase develop       # 履歴をきれいに統合（上級者向け）

---

## ■ リモート関連（重要）

git remote -v                    # リモート確認
git fetch                        # リモートの最新情報だけ取得
git pull origin develop          # developを取得＋マージ（推奨）
git push origin <branch>         # ブランチをリモートへ反映

---

## ■ 変更の取り消し・修正

git restore <file>               # ファイル変更を戻す
git reset HEAD <file>            # add取り消し
git reset --hard HEAD            # 全変更破棄（危険）
git stash                        # 一時退避（重要）
git stash pop                    # 退避を戻す
git commit --amend               # 直前コミット修正

---

## ■ 履歴の確認

git log                          # コミット履歴
git log --oneline                # 簡潔表示
git diff                         # 差分確認
git show                         # 直近コミット詳細

---

# ■ チーム開発フロー

## 前提
- develop = 最新の統合ブランチ
- features/* = 各メンバーの作業ブランチ

---

## ① 作業開始前（最新を取り込む）

git switch develop
git pull origin develop

git switch <自分のブランチ>
git merge develop

---

## ② 作業

git add .
git commit -m "作業内容"

---

## ③ 共有（必要なときのみ）

git push origin <自分のブランチ>

---

## 強制的に変更を破棄

git reset --hard
git clean -fd

※ 完全に消えるので注意
