#!/bin/bash
# scripts/setup-clusters.sh

# Переходим в корень проекта
cd "$(dirname "$0")/.." || exit 1

# Создаём нужные директории
mkdir -p timing results logs

START=$(date +%s)
echo "profile,seconds" | tee timing/minikube-profile-create-seconds.csv

for p in dev stage prod; do
  PROFILE_START=$(date +%s)

  # Удаляем старый профиль, если есть
  minikube delete -p "$p" 2>/dev/null

  # Создаём новый профиль
  if minikube start -p "$p" --driver=docker --cpus=2 --memory=4096; then
    minikube update-context -p "$p"
    kubectl create namespace secrets-lab --dry-run=client -o yaml | kubectl apply -f -
  else
    echo "ERROR: Failed to create profile $p" | tee -a logs/errors.log
    exit 1
  fi
  
  PROFILE_END=$(date +%s)
  echo "$p,$((PROFILE_END - PROFILE_START))" | tee -a timing/minikube-profile-create-seconds.csv
done

END=$(date +%s)
echo "$((END - START))" | tee timing/minikube-all-profiles-create-seconds.txt

echo "✅ Все кластеры созданы. Результаты в timing/"
