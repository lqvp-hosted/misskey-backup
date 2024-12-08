#!/bin/bash

# ユーザー設定
DB_USER="your_db_user"              # データベースのユーザー名を指定
DB_NAME="your_db_name"              # データベース名を指定
DOCKER_CONTAINER_NAME="misskey-db-1"  # Dockerコンテナ名を指定
BACKUP_DIR="/home/misskey/backup"   # 一時的なバックアップ保存先
DISCORD_WEBHOOK_URL="your_webhook_url"  # DiscordのWebhook URLを指定
GDRIVE_PARENT_ID="your_drive_folder_id" # Google Driveのアップロード先フォルダID
GDRIVE_PATH="/path/to/gdrive"       # gdriveコマンドのパス

# タイムスタンプ
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_backup_$TIMESTAMP.sql"
LAST_BACKUP=$(ls -t $BACKUP_DIR/${DB_NAME}_backup_*.sql 2>/dev/null | grep -v $TIMESTAMP | head -n 1)

# バックアップ開始通知
curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"📌 データベースのバックアップを開始します。\"}" $DISCORD_WEBHOOK_URL

# エラーハンドリング
set -o errexit
set -o pipefail
set -o nounset

{
    # バックアップディレクトリの作成
    mkdir -p $BACKUP_DIR

    # Dockerコンテナ内のデータベースをバックアップ
    docker exec $DOCKER_CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME > $BACKUP_FILE

    # 前回のバックアップサイズ取得
    if [ -f "$LAST_BACKUP" ]; then
        LAST_SIZE=$(stat -c%s "$LAST_BACKUP")
    else
        LAST_SIZE=0
    fi

    # 今回のバックアップサイズ取得
    CURRENT_SIZE=$(stat -c%s "$BACKUP_FILE")

    # サイズ差分計算
    SIZE_DIFF=$((CURRENT_SIZE - LAST_SIZE))

    # ファイルをGoogle Driveにアップロード
    GDRIVE_OUTPUT=$($GDRIVE_PATH files upload --parent $GDRIVE_PARENT_ID "$BACKUP_FILE")

    # アップロード結果からCreatedとViewUrlを抽出
    CREATED_TIME=$(echo "$GDRIVE_OUTPUT" | grep "Created:" | awk '{print $2" "$3}')
    VIEW_URL=$(echo "$GDRIVE_OUTPUT" | grep "ViewUrl:" | awk '{print $2}')

    # バックアップ完了通知
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"✅ データベースのバックアップが完了しました。\n前回との差分サイズ: ${SIZE_DIFF} バイト\n作成日時: ${CREATED_TIME}\nダウンロードURL: ${VIEW_URL}\"}" $DISCORD_WEBHOOK_URL

} || {
    # エラー時の処理
    ERROR_MESSAGE=$(cat /tmp/backup_error.log)
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"⚠️ バックアップ中にエラーが発生しました。\nエラー内容: ${ERROR_MESSAGE}\"}" $DISCORD_WEBHOOK_URL
} 2> /tmp/backup_error.log
