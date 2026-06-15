# Создаем директорию если её нет
mkdir -p timing

# Очищаем старый файл результатов
> timing/eso-first-working-secret-seconds.csv

for p in dev stage prod; do
  echo "=== Processing $p ==="
  kubectl config use-context "$p"
  
  # Удаляем ресурсы перед измерением
  echo "  Cleaning up..."
  kubectl delete externalsecret app-secrets -n secrets-lab --ignore-not-found=true
  kubectl delete secretstore fake-store -n secrets-lab --ignore-not-found=true
  kubectl delete secret app-secrets-k8s -n secrets-lab --ignore-not-found=true
  
  # Ждем полного удаления
  sleep 2
  
  # Замеряем время
  START=$(date +%s)
  echo "  Creating resources..."
  
  kubectl apply -f manifests/eso-fake.yaml
  
  kubectl wait --for=condition=Ready externalsecret/app-secrets \
    -n secrets-lab \
    --timeout=120s
  
  kubectl get secret app-secrets-k8s -n secrets-lab
  
  END=$(date +%s)
  
  ELAPSED=$((END - START))
  echo "$p,$ELAPSED" | tee -a timing/eso-first-working-secret-seconds.csv
  echo "  Done in ${ELAPSED}s"
  echo "---"
done

echo ""
echo "=== Final Results ==="
cat timing/eso-first-working-secret-seconds.csv
