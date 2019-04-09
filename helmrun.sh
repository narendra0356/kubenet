#!/bin/bash

# Install helm
kubectl create serviceaccount -n kube-system tiller

kubectl create clusterrolebinding tiller-binding \
	--clusterrole=cluster-admin \
	--serviceaccount kube-system:tiller

helm init --service-account tiller --upgrade --wait

# Deploy external DNS

helm install --name external-dns stable/external-dns \
	--set "provider=cloudflare" \
	--set "cloudflare.apiKey=b3ffb9cb02838364b2fb579c1f3b399b68c37" \
	--set "cloudflare.email=developers@impetusdigital.com"  \
	--set "annotationFilter=external-dns.alpha.kubernetes.io/hostname" \
	--set-string "rbac.create=true" 

# Test External DNS

kubectl --namespace=default get pods -l "app=external-dns,release=external-dns"

# Disable default loadbalancer ingress
gcloud container clusters update ${CLUSTER_NAME} \
	--update-addons [HttpLoadBalancing=DISABLED] --zone ${ZONE}

# Deploy nginx ingress controller

helm install stable/nginx-ingress --namespace nginx-ingress \
	 --name nginx-ingress \
	 --set controller.stats.enabled=true \
	 --set controller.metrics.enabled=true  \
 	 --set-string controller.publishService.enabled=true


# Install cert-manager for automatic SSL certs
helm install --name cert-manager stable/cert-manager  \
	--namespace kube-system \
	--set ingressShim.defaultIssuerName=letsencrypt-prod \
	--set ingressShim.defaultIssuerKind=ClusterIssuer


# Install the letsencrypt-prod issuer
IFS='' read -r -d '' CERT_ISSUER <<"EOF"
{
  "apiVersion": "certmanager.k8s.io/v1alpha1",
  "kind": "ClusterIssuer",
  "metadata": {
    "name": "letsencrypt-prod1"
  },
  "spec": {
    "acme": {
      "server": "https://acme-v02.api.letsencrypt.org/directory",
      "email": "ssl@impetusgcp.com",
      "privateKeySecretRef": {
        "name": "letsencrypt-prod1"
      },
      "http01": {
      }
    }
  }
}
EOF

echo ${CERT_ISSUER} | kubectl apply -f - 
