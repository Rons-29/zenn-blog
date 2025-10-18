#!/bin/bash

# Zenn記事の参考文献チェックスクリプト
# 使用方法: ./scripts/check-article.sh articles/記事名.md

ARTICLE_PATH="$1"

if [ -z "$ARTICLE_PATH" ]; then
    echo "使用方法: $0 articles/記事名.md"
    exit 1
fi

if [ ! -f "$ARTICLE_PATH" ]; then
    echo "エラー: ファイル '$ARTICLE_PATH' が見つかりません"
    exit 1
fi

echo "=== Zenn記事チェック: $ARTICLE_PATH ==="
echo

# 参考文献セクションの存在チェック
if grep -q "## 参考文献\|## 参考リンク\|## References" "$ARTICLE_PATH"; then
    echo "✅ 参考文献セクションが見つかりました"
else
    echo "❌ 参考文献セクションが見つかりません"
    echo "   記事の最後に以下のようなセクションを追加してください："
    echo "   ## 参考文献"
    echo "   - [参考資料のタイトル](URL)"
fi

# 参考リンクの存在チェック
if grep -q "\[.*\]\(http.*\)" "$ARTICLE_PATH"; then
    echo "✅ 参考リンクが見つかりました"
else
    echo "⚠️  参考リンクが見つかりません"
    echo "   参考にした資料がある場合はリンクを追加してください"
fi

# 参考文献セクション内のリンク数をカウント
if grep -q "## 参考文献\|## 参考リンク\|## References" "$ARTICLE_PATH"; then
    REF_SECTION=$(grep -A 20 "## 参考文献\|## 参考リンク\|## References" "$ARTICLE_PATH")
    REF_LINKS=$(echo "$REF_SECTION" | grep -c "\[.*\](https.*)" 2>/dev/null)
    
    if [ "$REF_LINKS" -gt 0 ]; then
        echo "✅ 参考文献セクション内に $REF_LINKS 個のリンクが見つかりました"
    else
        echo "⚠️  参考文献セクション内にリンクが見つかりません"
        echo "   参考にした資料のリンクを追加してください"
    fi
fi

# 引用の存在チェック
if grep -q "^> " "$ARTICLE_PATH"; then
    echo "✅ 引用が見つかりました"
else
    echo "ℹ️  引用は見つかりませんでした（参考にした内容がある場合は引用符で囲んでください）"
fi

# チェック結果の要約
echo
echo "=== チェック完了 ==="
echo "記事を公開する前に、WRITING_GUIDELINES.mdのチェックリストを確認してください。"