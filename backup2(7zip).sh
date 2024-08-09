#!/bin/bash

# Пути к лог-файлу и точкам монтирования
LOG_FILE="/mnt/srv-ts5-ad.log"
MOUNT_POINT1="/mnt/srv-ts5-ad"
MOUNT_POINT2="/mnt/srv-ts5-ad-tr"

# Telegram Bot API параметры
TOKEN="1115999333:dddmuRf8mAfEpSjXZLdffghhlQu0jY"
CHAT_ID="116667787"

# Название скрипта для уведомлений
SCRIPT_NAME="Резервное копирование srv-ts5_c_ad:\*"

# Функция для записи логов и отправки уведомлений
log_and_notify() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $message" >> $LOG_FILE
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id=$CHAT_ID -d text="$SCRIPT_NAME: $message" > /dev/null
}

# IP адреса компьютеров
HOST1="192.168.2.13"
HOST2="192.168.2.200"

# Пароль для архива
ZIP_PASSWORD="1234567890"

# Создание имени архива на основе текущей даты
DATE=$(date '+%Y-%m-%d-%H:-%M:-%S')
ARCHIVE_NAME="srv-ts5-ad_backup_$DATE.7z"

# Проверка доступности хостов
ping -c 1 $HOST1 > /dev/null 2>&1
HOST1_STATUS=$?

ping -c 1 $HOST2 > /dev/null 2>&1
HOST2_STATUS=$?

# Если оба хоста доступны
if [ $HOST1_STATUS -eq 0 ] && [ $HOST2_STATUS -eq 0 ]; then
    log_and_notify "✅ Оба хоста доступны, монтируем шары..."

    # Монтируем шару с первого хоста
    sudo mount -t cifs //192.168.2.13/c$/Users/use1 $MOUNT_POINT1 -o username=admin1,password=123,domain=fm.loc,iocharset=utf8,file_mode=0777,dir_mode=0777
    MOUNT1_STATUS=$?

    # Монтируем шару со второго хоста
    sudo mount -t cifs //192.168.2.200/srv-win/srv-ts $MOUNT_POINT2 -o username=admin2,password=123,domain=workgroup,iocharset=utf8,file_mode=0777,dir_mode=0777
    MOUNT2_STATUS=$?

    # Если монтирование прошло успешно
    if [ $MOUNT1_STATUS -eq 0 ] && [ $MOUNT2_STATUS -eq 0 ]; then
        log_and_notify "✅ Шары успешно примонтированы, выполняем архивирование..."

        # Проверка наличия папок перед архивированием
        if [ -d "$MOUNT_POINT1/Downloads" ] && [ -d "$MOUNT_POINT1/Documents" ] && [ -d "$MOUNT_POINT1/Desktop" ]; then
            # Архивируем только папки Загрузки, Документы и Рабочий стол с использованием 7zip
            7z a -p$ZIP_PASSWORD "/mnt/$ARCHIVE_NAME" "$MOUNT_POINT1/Downloads" "$MOUNT_POINT1/Documents" "$MOUNT_POINT1/Desktop"
            ZIP_STATUS=$?

            if [ $ZIP_STATUS -eq 0 ]; then
                log_and_notify "✅ Архивирование успешно завершено: $ARCHIVE_NAME."

                # Копирование архива на второй хост
                cp /mnt/$ARCHIVE_NAME $MOUNT_POINT2/
                CP_STATUS=$?

                if [ $CP_STATUS -eq 0 ]; then
                    log_and_notify "✅ Архив успешно скопирован на второй хост."
                else
                    log_and_notify "❌ Ошибка при копировании архива на второй хост."
                fi
            else
                log_and_notify "❌ Ошибка при создании архива."
            fi
        else
            log_and_notify "❌ Одна или несколько папок (Загрузки, Документы, Рабочий стол) не найдены."
        fi

        # Размонтируем шары
        log_and_notify "🔄 Выполняем отмонтирование..."
        sudo umount $MOUNT_POINT1
        sudo umount $MOUNT_POINT2
        log_and_notify "✅ Шары успешно отмонтированы."
    else
        log_and_notify "❌ Не удалось примонтировать одну или обе шары."

        # Попытка размонтирования в случае частичного монтирования
        if mount | grep $MOUNT_POINT1 > /dev/null; then
            sudo umount $MOUNT_POINT1
        fi
 
        if mount | grep $MOUNT_POINT2 > /dev/null; then
            sudo umount $MOUNT_POINT2
        fi
    fi
else
    log_and_notify "❌ Один или оба хоста недоступны."
fi
