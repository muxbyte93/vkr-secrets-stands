#!/bin/bash
# scripts/check-clusters.sh
echo "=== Проверка состояния кластеров ==="
echo ""
for p in dev stage prod; do
  echo "📦 Кластер: $p"
  echo "─────────────────────────────────────"
  
  # Переключаем контекст
  if kubectl config use-context "$p" 2>/dev/null; then
    # Проверяем ноды
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    echo "✅ Узлов: $NODE_COUNT"
    
    # Проверяем namespace
    if kubectl get ns secrets-lab &>/dev/null; then
      echo "✅ Namespace secrets-lab: существует"
    else
      echo "❌ Namespace secrets-lab: НЕ СУЩЕСТВУЕТ"
    fi
  else
    echo "❌ Не удалось переключиться на контекст $p (кластер не запущен?)"
  fi
  
  echo ""
done
echo "=== Текущий активный кластер ==="
kubectl config current-context
