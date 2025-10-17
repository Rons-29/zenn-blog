# GitHubリポジトリ作成とZenn連携設定手順

## 1. GitHubリポジトリの作成

### 手順
1. [GitHub](https://github.com)にログイン
2. 右上の「+」ボタンから「New repository」を選択
3. リポジトリ名を入力（例：`zenn-blog`）
4. 説明を入力（例：`My Zenn blog articles`）
5. 公開設定を選択（PublicまたはPrivate）
6. 「Create repository」をクリック

### 注意事項
- README.md、.gitignore、ライセンスファイルは作成しない（既にローカルにあるため）
- リポジトリは最大2つまで連携可能

## 2. ローカルリポジトリとGitHubの連携

### リモートリポジトリの追加
```bash
cd /Users/shirokki22/project/zenn-blog
git remote add origin https://github.com/YOUR_USERNAME/zenn-blog.git
```

### 初回プッシュ
```bash
git branch -M main
git push -u origin main
```

## 3. Zennとの連携設定

### 手順
1. [Zenn](https://zenn.dev)にログイン
2. ダッシュボードの「GitHubからのデプロイ」を開く
3. 「リポジトリを連携」をクリック
4. 作成したGitHubリポジトリを選択
5. 「Only select repositories」にチェックを入れる
6. 連携を完了

### 同期ブランチの設定
1. リポジトリ設定タブで同期したいブランチ名を確認
2. デフォルトは`main`ブランチ
3. 必要に応じてブランチ名を変更

## 4. 動作確認

### 記事のプレビュー
```bash
npx zenn preview
```

### 記事の公開
1. 記事の`published: false`を`published: true`に変更
2. 変更をコミット・プッシュ
3. Zennで自動デプロイを確認

## 5. 今後の作業フロー

1. ローカルで記事を執筆
2. `npx zenn preview`でプレビュー
3. `git add .`で変更をステージング
4. `git commit -m "記事のタイトル"`でコミット
5. `git push`でGitHubにプッシュ
6. Zennで自動デプロイを確認

## トラブルシューティング

### デプロイされない場合
1. Zennダッシュボードのデプロイ履歴を確認
2. エラーメッセージを確認
3. GitHubの権限設定を確認

### 権限エラーの場合
1. GitHubの「Settings」→「Applications」→「Zenn Connect」を確認
2. リポジトリへのアクセス権限を確認
3. 必要に応じて権限を再設定
