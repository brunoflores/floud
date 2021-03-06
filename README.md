# floud
The Flores private Cloud.

```sh
$ terraform apply \
    -target=google_compute_network.floud \
    -target=module.k8s.google_compute_address.kubernetes
$ terraform apply
$ kubectl apply -f modules/k8s/config/
$ kubectl apply -f secrets/secret-bootstrap-token-07401b.yaml
$ kubectl apply -f coredns.yaml
$ kubectl patch storageclass slow -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Helm 2

See https://stackoverflow.com/questions/46672523/helm-list-cannot-list-configmaps-in-the-namespace-kube-system

```sh
$ helm init
$ kubectl create serviceaccount --namespace kube-system tiller
$ kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
$ kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
$ helm init --service-account tiller --upgrade
```

## Vault

```sh
$ helm3 install --values helm-vault-values.yml vault /Users/brunoflores/devel/vault-helm/
$ kubectl exec -it vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > cluster-keys.json
$ kubectl exec -it vault-0 -- vault operator unseal $(cat cluster-keys.json | jq -r ".unseal_keys_b64[]")
```

## GCP

These are the roles on the service account required by the GCE Cloud Provider on
Kubernetes.

https://kubernetes.io/docs/concepts/cluster-administration/cloud-providers/

https://github.com/kubernetes/cloud-provider-gcp

https://stackoverflow.com/questions/50100219/kubernetes-failed-to-get-gce-gcecloudprovider-with-error-nil

```sh
$ gcloud projects add-iam-policy-binding bruno-flores \
    --member serviceAccount:gce-k8s-user@bruno-flores.iam.gserviceaccount.com \
    --role roles/compute.instanceAdmin.v1
$ gcloud projects add-iam-policy-binding bruno-flores \
    --member serviceAccount:gce-k8s-user@bruno-flores.iam.gserviceaccount.com \
    --role roles/iam.serviceAccountUser
$ gcloud projects add-iam-policy-binding bruno-flores \
    --member serviceAccount:gce-k8s-user@bruno-flores.iam.gserviceaccount.com \
    --role roles/compute.storageAdmin
$ gcloud projects add-iam-policy-binding bruno-flores \
    --member serviceAccount:gce-k8s-user@bruno-flores.iam.gserviceaccount.com \
    --role roles/compute.networkAdmin
```
