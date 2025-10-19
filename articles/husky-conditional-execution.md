---
title: '大規模TS×AI開発のHusky設計：失敗許容と閾値ガードで「止めない」品質改善'
emoji: "🔧"
type: "tech"
topics: ["husky", "typescript", "eslint", "git", "ci-cd", "ai-development", "mlops", "llm"]
published: false
---

# はじめに

近年、AIアプリケーションや機械学習基盤のような大規模TypeScriptプロジェクトでは、型定義や静的解析の複雑化が進み、開発が止まるほどの型エラーを抱えることも珍しくありません。

AI開発では、実験的なコードと本番コードが混在しやすく、動的な型推論と静的型検証の境界問題が頻発します。特にLLMアプリケーションやMLツールチェーンでは、型定義の拡張や動的コード生成により、従来の静的解析ツールが機能不全に陥りがちです。

本記事では、600個のTypeScriptエラーを抱えたAI開発プロジェクトで、Huskyの条件付き実行機能を活用して開発を継続し、段階的に品質を向上させた実践例を紹介します。この「戦略的エラー許容」アプローチは、品質を崩さずにスピードを維持するための現実的な解決策として、AI開発現場で広く応用可能です。

## 本稿の前提と適用範囲

- **対象**: モノレポ/ワークスペース構成のTypeScriptプロジェクト（AI/ML基盤を含む）
- **目的**: 開発を止めず品質を段階的に回復する
- **非目的**: pre-commitでモノレポ全体の厳格チェックを常時強制すること
- **安全フェンス**:
  1. pre-commitは変更ファイル限定の高速チェック
  2. pre-push/CIでフルチェック＋エラー増加ブロック
  3. スキップ用環境変数はローカル限定・CI無効

## 問題の背景

### AI開発における技術負債の特徴

AI開発プロジェクトでは、以下のような特有の課題が技術負債を蓄積しやすくなります：

- **動的型生成**: LLMの出力やAPIレスポンスの型定義が動的に変化
- **実験コードの混在**: プロトタイプと本番コードの境界が曖昧
- **依存関係の複雑化**: MLライブラリとWebフレームワークの型定義競合
- **CI/CDの重複**: データパイプラインとアプリケーションの異なる品質基準

### プロジェクトの状況

- **TypeScriptエラー**: 600個の既存エラー
- **プロジェクト構造変更**: `packages/` → `qa-workbench/` への移行
- **ESLint設定エラー**: `@typescript-eslint/recommended`の設定不足
- **バックエンド依存関係不足**: `better-sqlite3`等のコンパイルエラー

### 課題

既存のエラーをすべて修正するには膨大な時間がかかるため、開発を継続しながら段階的に品質を向上させる仕組みが必要でした。特にAI開発では、実験的な機能追加と安定性の両立が求められるため、従来の「すべてのエラーを修正してから開発継続」というアプローチは現実的ではありません。

## 解決アプローチ

### 1. プロジェクト構造の自動検出

Huskyの設定で、新旧両方のプロジェクト構造に対応できるよう自動検出機能を実装しました。

**注**: pre-commit は最短フィードバックを目的とし、変更差分にのみ静的解析を適用します。型情報必須の重いルールは pre-push/CI に限定し、体感速度を落とさない設計です。

```bash
find_project_dir() {
  for rel_path in "$@"; do
    project_dir="$ROOT_DIR/$rel_path"
    if [ -d "$project_dir" ] && [ -f "$project_dir/package.json" ]; then
      printf '%s\n' "$project_dir"
      return 0
    fi
  done
  return 1
}
```

### 2. 条件付き実行の実装

環境変数を使用して、TypeScriptチェックとESLintチェックを個別に制御できるようにしました。

**本記事は ESLint Flat Config（eslint.config.js）前提です。従来の .eslintrc* 利用時はルール解釈・プラグイン解決が異なるため、ここでのコマンドやルール例は適宜読み替えてください。**

```bash
# 環境変数でTypeScriptチェックを制御
if [ "${SKIP_TYPESCRIPT_CHECK:-false}" = "true" ]; then
  echo "ℹ️ 環境変数によりTypeScriptチェックをスキップします"
else
  run_npm_script "$FRONTEND_DIR" "type-check" "📝 フロントエンド型チェック中..." "❌ フロントエンド型チェックに失敗しました" "true"
fi

# 環境変数でESLintチェックを制御
if [ "${SKIP_ESLINT_CHECK:-false}" = "true" ]; then
  echo "ℹ️ 環境変数によりESLintチェックをスキップします"
else
  run_npm_script "$FRONTEND_DIR" "lint" "🔧 フロントエンドESLintチェック中..." "❌ フロントエンドESLintチェックに失敗しました" "true"
fi
```

### 3. エラー許容機能の追加

`run_npm_script`関数に`allow_failure`パラメータを追加し、エラーが発生しても処理を継続できるようにしました。

```bash
has_npm_script() {
  local dir="$1" name="$2"
  [ -f "$dir/package.json" ] && command -v jq >/dev/null 2>&1 \
    && jq -e --arg s "$name" '.scripts[$s]?' "$dir/package.json" >/dev/null
}

run_npm_script() {
  local project_dir="$1" script_name="$2" start_message="$3" failure_message="$4" allow_failure="${5:-false}"

  if ! has_npm_script "$project_dir" "$script_name"; then
    echo "ℹ️ $(basename "$project_dir") に ${script_name} は見つかりません。スキップ"
    return 0
  fi

  echo "$start_message"
  if (cd "$project_dir" && npm run --silent "$script_name"); then
    return 0
  fi

  if [[ "$allow_failure" == "true" ]]; then
    echo "⚠️ $(basename "$project_dir") の ${script_name} は失敗しましたが継続します"
    return 0
  fi

  echo "$failure_message"
  return 1
}
```

**改善点**:
- 戻り値は `return` に統一（フック本体でまとめて `set -e`）
- `jq` 依存を明記（`package.json` の解析に必要）
- ログは `--silent` でコンパクトに
- 未定義関数の呼び出しを修正

## 実装結果

### 成功したこと

- **コミット可能な状態を実現**: 失敗許容ロジックでチェックエラーを許容
- **プロジェクト構造の柔軟性**: 新旧両方の構造に対応
- **段階的品質改善**: 既存エラーを抱えながら開発継続
- **エラー数の減少**: 600個 → 484個（116個解決）
- **環境変数による制御**: 必要に応じてチェックを完全にスキップ可能

### 使用方法

```bash
# 通常: 変更ファイル限定の高速チェック（pre-commitで自動実行）
git commit -m "feat: 新機能追加"

# 例外（ローカルのみ・緊急時のみ）: 一時的に pre-commit をスキップ
# ※ pre-push と CI では常にフルチェックが走り、スキップは無効
SKIP_PRECOMMIT=true git commit -m "wip: ホットフィックス"

# どうしても型/ESLintをローカルでスキップしたい場合（ローカル限定）
SKIP_TYPESCRIPT_CHECK=true SKIP_ESLINT_CHECK=true git commit -m "wip: 実験コード"
```

**重要**: CI・pre-push では SKIP_* を無視します。ローカルの緊急作業を許容しつつ、リモートに不良が流れないようにします。

```bash
# .husky/pre-push の冒頭で品質ゲートを実装
# 品質ゲート：ローカル専用のスキップ変数は無効化
unset SKIP_TYPESCRIPT_CHECK
unset SKIP_ESLINT_CHECK
unset SKIP_PRECOMMIT
```

失敗許容は緊急のローカル作業に限定します。レビュー対象のブランチや共有リポジトリでは利用禁止をチーム規約に明記してください。pre-push/CIでは強制的に無効化されます（コード参照）。

## 段階的修正の計画

### Phase 1: 依存関係の修復 ✅

- フロントエンド: `clsx`, `tailwind-merge`, `jspdf`のインストール完了
- バックエンド: 依存関係の修復（進行中）
- **Exit基準**: 全パッケージの依存関係エラー解消

**注**: pre-commit では ビルド/コンパイルを走らせません。tsc --noEmit に限定し、ネイティブ依存（例: better-sqlite3）のビルド可否は pre-push/CI のコンテナ/ビルドジョブで検証します。

### Phase 2: ESLint設定の修復 🔄

- `@typescript-eslint/recommended`の設定修正
- 設定ファイルの最適化
- **Exit基準**: eslintErrors <= 450（baseline更新）

### Phase 3: TypeScriptエラーの段階的修正 📋

- 重要なファイルから優先的に修正
- `exactOptionalPropertyTypes`関連エラーの整理
- 型定義の改善
- **Exit基準**: tscErrors <= 300、exactOptionalPropertyTypes を境界層に導入完了

### Phase 4: 最終的な品質向上 🎯

- 環境変数なしでフルチェック可能に
- 継続的インテグレーションの強化
- **Exit基準**: pre-commit から SKIP_* 利用ゼロ／月、CI 連続グリーン 14日

### 計測と可視化

```bash
# エラー件数の計測
npm run lint:ci --format json > artifacts/eslint.json
tsc --pretty false --noEmit | tee artifacts/tsc.txt

# 閾値ガード用のbaseline更新
node scripts/update-baseline.mjs
```

**重要**: 各PhaseのExit基準を満たすまで次のPhaseに進まないことで、段階的な品質向上を保証します。

## AI特有の型破綻にどう向き合うか（実装パターン）

ここでの「AI開発」は、LLMや外部推論APIを伴うWeb/サービス実装を指し、動的スキーマ（入出力の揺れ）を扱う境界層を含みます。本稿の対策は**その境界層を"まず守る"**ための運用設計です。

AI開発では、従来の静的解析では対応困難な型破綻が頻発します。以下に、TypeScript運用と組み合わせた具体的な対処法を示します。

### ランタイム検証の前置き
LLM/外部API応答は動的なため、実行時バリデーションを前置きして静的型に昇格させます。

```typescript
// zod/valibot/arktype 等で実行時バリデーション
const LLMResponseSchema = z.object({
  content: z.string(),
  confidence: z.number().min(0).max(1),
  metadata: z.record(z.unknown())
});

// 実行時検証後、静的型に昇格
type LLMResponse = z.infer<typeof LLMResponseSchema>;
```

### スキーマ駆動開発
OpenAPI/JSON Schemaから自動型生成し、型定義の発散を抑制します。

```bash
# スキーマから型定義を自動生成
npx openapi-typescript schema.json -o types/api.ts
```

### 生成コードの隔離
動的生成されるコードは専用ディレクトリに隔離し、段階的に導入します。

```json
// tsconfig.json
{
  "include": ["src/**/*"],
  "exclude": ["generated/**/*", "node_modules"]
}

// generated/ は別のtsconfigで管理
// generated/tsconfig.json
{
  "extends": "../tsconfig.json",
  "compilerOptions": {
    "strict": false
  }
}
```

### exactOptionalPropertyTypesの段階導入
境界層（外部I/O）から適用し、内側へ拡張します。

```typescript
// 境界層から開始
interface APIResponse {
  data: string;
  error?: string; // undefined と "" を区別
}

// 内側の型定義は後から適用
interface InternalState {
  status: 'loading' | 'success' | 'error';
  data?: string; // 段階的に strict に移行
}
```

### 影響範囲ビルド
turbo/nx/自作スクリプトで変更影響範囲のみに厳格チェックを適用します。

```bash
# turbo を使用した影響範囲チェック
turbo run lint type-check --filter=...[HEAD~1]

# CIでは比較対象を環境変数で注入して漏れを防ぐ
turbo run lint type-check --filter=...[${BASE_SHA:-origin/main}]

# 自作スクリプトの場合
node scripts/check-affected.mjs
```

## 学んだこと

### 1. AI開発における柔軟性の重要性

AI開発では、実験的な機能追加と安定性の両立が求められます。完璧を求めすぎると開発が停滞してしまうため、段階的なアプローチが不可欠です。特にLLMアプリケーションでは、型定義が動的に変化するため、従来の静的解析の限界を理解し、戦略的にエラーを許容することが重要です。

### 2. 環境変数による制御の威力

条件付き実行により、状況に応じてチェックレベルを調整できる柔軟性を実現しました。AI開発では、実験フェーズと本番フェーズで異なる品質基準が必要なため、この制御機能は特に有効です。

### 3. プロジェクト構造の変化への対応

自動検出機能により、プロジェクト構造が変更されてもHuskyの設定を維持できました。AI開発では、MLOpsパイプラインの変更や新しいライブラリの導入が頻繁に発生するため、この柔軟性は必須です。

### 4. AI開発特有の課題への対応

動的型生成や実験コードの混在といったAI開発特有の課題に対して、従来の静的解析ツールだけでは対応が困難です。Huskyの条件付き実行機能を活用することで、これらの課題を現実的に解決できることが分かりました。

## まとめ

Huskyの条件付き実行機能を活用することで、既存のエラーを抱えたままでも開発を継続し、段階的に品質を向上させることができました。この「戦略的エラー許容」アプローチは、AI開発のような技術負債を抱えやすい現場で特に有効です。

AI開発では、動的型生成や実験コードの混在により、従来の静的解析ツールでは対応困難な課題が頻発します。しかし、Huskyの柔軟な制御機能により、これらの課題を現実的に解決できることが分かりました。

今後は、段階的修正計画に従って、最終的に環境変数なしでフルチェックが通る状態を目指します。このアプローチは、機械学習エンジニアやLLMアプリ開発者にとって、品質とスピードを両立させる実践的な解決策として広く応用可能です。

## 参考文献

- [Husky公式ドキュメント](https://typicode.github.io/husky/) - Huskyの設定方法（現行版）
- [TypeScript公式ドキュメント](https://www.typescriptlang.org/docs/) - TypeScriptの型システム（現行版）
- [ESLint Flat Config移行ガイド](https://eslint.org/docs/latest/use/configure/configuration-files) - 新しい設定形式への移行（現行版）
- [@typescript-eslint 型情報ルール](https://typescript-eslint.io/rules/) - 型情報が必要なルールと不要なルールの分類（現行版）
- [Git Hooks公式ドキュメント](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks) - Gitフックの仕組み（現行版）
- [Turbo影響範囲実行](https://turbo.build/repo/docs/core-concepts/monorepos/filtering) - 変更影響範囲の効率的なチェック（現行版）
- [MLOps Best Practices](https://ml-ops.org/) - 機械学習運用のベストプラクティス（現行版）
- [AI開発における型安全性の課題](https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html) - TypeScript公式ガイド（現行版）
- [Zod公式ドキュメント](https://zod.dev/) - ランタイム型検証ライブラリ（現行版）
- [OpenAPI TypeScript Generator](https://openapi-ts.pages.dev/) - スキーマ駆動型生成（現行版）

## 付録：実装スクリプト

### scripts/tsc-changed.mjs（変更ファイル限定型チェック）

```javascript
import { execSync } from 'child_process';
import { readFileSync } from 'fs';

// 変更されたTypeScriptファイルを取得
const changedFiles = execSync('git diff --name-only --cached', { encoding: 'utf8' })
  .split('\n')
  .filter(file => file.endsWith('.ts') || file.endsWith('.tsx'));

if (changedFiles.length === 0) {
  console.log('変更されたTypeScriptファイルがありません');
  process.exit(0);
}

// 該当パッケージのtsconfigを検出して型チェック実行
for (const file of changedFiles) {
  const packageDir = file.split('/')[0];
  try {
    execSync(`cd ${packageDir} && npx tsc --noEmit`, { stdio: 'inherit' });
  } catch (error) {
    console.error(`型チェックエラー: ${file}`);
    process.exit(1);
  }
}
```

### scripts/update-baseline.mjs（エラー基準値更新）

```javascript
import { execSync } from 'child_process';
import { writeFileSync, mkdirSync } from 'fs';

// エラー件数を計測
const eslintErrors = execSync('npm run lint:ci --format json', { encoding: 'utf8' })
  .split('\n')
  .filter(line => line.includes('"severity":2'))
  .length;

const tscErrors = execSync('npx tsc --pretty false --noEmit 2>&1', { encoding: 'utf8' })
  .split('\n')
  .filter(line => line.includes('error TS'))
  .length;

// 基準値を更新
mkdirSync('artifacts', { recursive: true });
writeFileSync('artifacts/errors-baseline.json', JSON.stringify({
  eslintErrors,
  tscErrors,
  timestamp: new Date().toISOString()
}, null, 2));

console.log(`基準値更新: ESLint=${eslintErrors}, TypeScript=${tscErrors}`);
```

### scripts/guard-error-threshold.mjs（エラー増加ブロック）

```javascript
import { readFileSync } from 'fs';

try {
  const latest = JSON.parse(readFileSync('artifacts/errors-latest.json', 'utf8'));
  const baseline = JSON.parse(readFileSync('artifacts/errors-baseline.json', 'utf8'));

  const worse = latest.tscErrors > baseline.tscErrors || 
                latest.eslintErrors > baseline.eslintErrors;

  if (worse) {
    console.error('❌ エラー件数が増加しました。push を中断します。');
    process.exit(1);
  }
  console.log('✅ エラー件数は悪化していません。');
} catch (error) {
  console.log('ℹ️ 基準値ファイルが見つかりません。初回実行として継続します。');
}
```

## 想定ツッコミ → 即応答

**Q: 失敗許容って結局"甘え"では？**
A: pre-commit は差分のみの軽量検査で速度最優先。厳格検査は pre-push/CI に寄せ、エラー増加ブロックで品質低下を物理的に止めます。SKIP_* は CIで無効（コード参照）。

**Q: LLMの揺れる出力に型なんて当てられないのでは？**
A: ランタイム検証前置き + 型への昇格（zod 等）で境界を固定します。内側は exactOptionalPropertyTypes を段階導入。

**Q: turbo/nx がないと再現できない？**
A: 影響範囲は 自作スクリプトでも可（付録参照）。ツール非依存の設計です。
