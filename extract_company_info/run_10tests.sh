#!/bin/bash
# 10件のテストを順次実行し、成功/失敗をカウント

cd "$(dirname "$0")"
source venv/bin/activate

SUCCESS_COUNT=0
FAILURE_COUNT=0
TOTAL=10

echo "========================================="
echo "10件テスト開始（待機時間:各テスト後10秒）"
echo "========================================="

for i in $(seq 1 10); do
    TEST_ID=$(printf "test%03d" $i)
    echo ""
    echo "[$i/$TOTAL] テスト実行中: $TEST_ID"
    echo "-----------------------------------------"
    
    # JSONからテストケースを抽出（jqを使用）し、app.pyが期待する形式に変換
    if command -v jq >/dev/null 2>&1; then
        cat test_10cases.json | jq -c ".[$((i-1))] | {customer_id: .customer_id, event: \"input\", json: tojson}" | timeout 300 python app.py > "test_output_${TEST_ID}.json" 2>&1
    else
        echo "エラー: jqがインストールされていません"
        exit 1
    fi
    
    EXIT_CODE=$?
    
    # 結果を確認
    if [ $EXIT_CODE -eq 0 ]; then
        # successフィールドを確認
        SUCCESS=$(cat "test_output_${TEST_ID}.json" 2>/dev/null | jq -r '.success' 2>/dev/null)
        if [ "$SUCCESS" = "true" ]; then
            echo "✅ 成功"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "❌ 失敗（APIエラーまたはバリデーションエラー）"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
        fi
    else
        echo "❌ 失敗（タイムアウトまたは実行エラー）"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
    fi
    
    # 次のテストまで待機（最後のテスト以外）
    if [ $i -lt $TOTAL ]; then
        echo "⏳ 次のテストまで10秒待機..."
        sleep 10
    fi
done

echo ""
echo "========================================="
echo "テスト完了"
echo "========================================="
echo "成功: $SUCCESS_COUNT/$TOTAL"
echo "失敗: $FAILURE_COUNT/$TOTAL"
echo "成功率: $(awk "BEGIN {printf \"%.1f\", ($SUCCESS_COUNT/$TOTAL)*100}")%"
echo "========================================="

# 成功率が100%でない場合は終了コード1
if [ $SUCCESS_COUNT -eq $TOTAL ]; then
    exit 0
else
    exit 1
fi

