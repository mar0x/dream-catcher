#!/bin/bash
set -e
# -------------------------------
# Дата и счётчик
# -------------------------------
counter=1
YY=$(date +%y)
MM=$(date +%m)
DD=$(date +%d)

# Временная папка с видео
tmp_folder="/home/vlad/Desktop/playback"
mkdir -p "$tmp_folder/${YY}${MM}${DD}"
# Сетевая папка (SMB)
smb_folder="/mnt/myshare"

# -------------------------------
# Копия исходника
# -------------------------------
cp "$tmp_folder/tmp.mp4" "$tmp_folder/tmp_copy.mp4"

# -------------------------------
# Убираем первые замершие кадрики
# -------------------------------
ffmpeg -hide_banner -ss 0.4 -i "$tmp_folder/tmp_copy.mp4" -c copy -y "$tmp_folder/tmp_post.mp4"
tmp_rec="$tmp_folder/tmp_post.mp4"

# -------------------------------
# Скриншот таймкода (камера Venice)
# -------------------------------
ffmpeg -hide_banner -loglevel error -y -ss 0 \
    -i "$tmp_rec" \
    -vf "crop=235:40:0:1035" \
    -frames:v 1 -y "$tmp_folder/frame_TC.jpg" >/dev/null 2>&1

# -------------------------------
# OCR таймкода
# -------------------------------
tesseract "$tmp_folder/frame_TC.jpg" "$tmp_folder/tmp_TC" \
    -l eng --oem 1 --psm 7 \
    -c tessedit_char_whitelist=:0123456789 >/dev/null 2>&1

TIMECODE=$(grep -oE '[0-9]{2}(:[0-9]{2}){3}' "$tmp_folder/tmp_TC.txt" | head -n 1)

if [[ -z "$TIMECODE" ]]; then
    echo "ERROR: Could not detect timecode from image."
    exit 1
fi

echo "Detected timecode: $TIMECODE"

# -------------------------------
# Прописываем таймкод в файл
# -------------------------------
ffmpeg -hide_banner -loglevel error \
    -i "$tmp_rec" -timecode "$TIMECODE" \
    -c copy -y "$tmp_folder/tmp_TC.mp4"

# -------------------------------
# Скриншот имени (камера Venice)
# -------------------------------
ffmpeg -hide_banner -loglevel error -y -ss 0 \
    -i "$tmp_folder/tmp_TC.mp4" \
    -vf "fps=1,crop=250:48:265:1032" \
    -frames:v 1 -y "$tmp_folder/frame.jpg" >/dev/null 2>&1

# -------------------------------
# OCR имени
# -------------------------------
tesseract "$tmp_folder/frame.jpg" "$tmp_folder/tmp" >/dev/null 2>&1

ocrtext=$(head -n 1 "$tmp_folder/tmp.txt")
ocrtext=$(echo "$ocrtext" | tr -d ' /\\?*<>|')

if [[ -n "$ocrtext" ]]; then
    filename="${ocrtext}_${YY}${MM}${DD}"
else
    filename="UNNAMED_${YY}${MM}${DD}"
fi

# -------------------------------
# Проверка существования имени файла в папке
# -------------------------------
while [[ -e "$tmp_folder/${YY}${MM}${DD}/$filename.mp4" ]]; do
    filename="${ocrtext}_${YY}${MM}${DD}_${counter}"
    counter=$((counter + 1))
done

mv "$tmp_folder/tmp_TC.mp4" "$tmp_folder/${YY}${MM}${DD}/$filename.mp4"

# -------------------------------
# Очистка
# -------------------------------
rm -f \
    "$tmp_folder/frame.jpg" \
    "$tmp_folder/frame_TC.jpg" \
    "$tmp_folder/tmp.txt" \
    "$tmp_folder/tmp_TC.txt" \
    "$tmp_folder/tmp_post.mp4" \
    "$tmp_folder/tmp_copy.mp4"
    
# -------------------------------
# Копирование в SMB
# -------------------------------
# dest_file_path="$smb_folder/${YY}${MM}${DD}/$filename.mp4"
# mkdir -p "$dest_file_path/${YY}${MM}${DD}"
# while [[ -e "$dest_file_path" ]]; do
#    dest_file_path="$smb_folder/${YY}${MM}${DD}/${filename}_${counter}.mp4"
#    counter=$((counter + 1))
# done

# cp "$tmp_folder/${YY}${MM}${DD}/$filename.mp4" "$dest_file_path"
# rsync -av --ignore-existing --size-only "$tmp_folder/${YY}${MM}${DD}/" "$smb_folder/${YY}${MM}${DD}/"
# read -p "Press Enter to continue..."    

