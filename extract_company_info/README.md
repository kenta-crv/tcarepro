# セットアップ手順
1. pip install -r requirements.txtを実行
2. .env.exampleを.envに変更し、GOOGLE_API_KEYを入力
3. crawl4ai-setupコマンドを実行
# 除外URLについて
.envの「EXCLUDE_DOMAIN_LIST」に改行区切りで入力。
ここで指定した文字列を含むWebサイトは抽出から除外される