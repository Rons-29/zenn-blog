---
title: "ZennとGitHubの連携を設定してみた"
emoji: "🚀"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["zenn", "github", "cli", "markdown"]
published: true
---

# はじめに

この記事では、ZennとGitHubの連携を設定する方法について説明します。

## 設定手順

### 1. Zenn CLIのインストール

```bash
npm install -g zenn-cli
```

### 2. プロジェクトの初期化

```bash
zenn init
```

### 3. 記事の作成

```bash
npx zenn new:article
```

## まとめ

ZennとGitHubの連携により、ローカルで記事を執筆し、GitHubにプッシュするだけで自動的にZennに公開できるようになります。

これにより、以下のメリットがあります：

- ローカルエディタでの執筆
- バージョン管理
- 自動デプロイ
- プレビュー機能

## 参考リンク

- [Zenn公式ドキュメント](https://zenn.dev/zenn/articles/connect-to-github)
