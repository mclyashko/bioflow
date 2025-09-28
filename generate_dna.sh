#!/bin/bash

LENGTH=${1:-1000000000}
OUTPUT_FILE=${2:-dna_sequence.txt}

CHUNK_SIZE=10000000

> "$OUTPUT_FILE"

echo "Генерируем $LENGTH нуклеотидов в файл $OUTPUT_FILE..."

generated=0
while [ $generated -lt $LENGTH ]; do
  remaining=$((LENGTH - generated))
  if [ $remaining -lt $CHUNK_SIZE ]; then
    current_chunk=$remaining
  else
    current_chunk=$CHUNK_SIZE
  fi

  awk -v len="$current_chunk" 'BEGIN {
    srand();
    for(i=1;i<=len;i++){
      r=int(rand()*4);
      if(r==0){printf "A"} else if(r==1){printf "C"} else if(r==2){printf "G"} else {printf "T"}
    }
  }' >> "$OUTPUT_FILE"

  generated=$((generated + current_chunk))
  echo "Сгенерировано $generated / $LENGTH"
done

echo "Генерация завершена!"
