for p in dev stage prod; do
  kubectl config use-context "$p"

  START=$(date +%s)

  helm upgrade --install external-secrets external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --set installCRDs=true

  kubectl wait --for=condition=Available deployment/external-secrets \
    -n external-secrets \
    --timeout=180s

  END=$(date +%s)

  echo "$p,$((END - START))" | tee -a timing/eso-install-seconds.csv
done
