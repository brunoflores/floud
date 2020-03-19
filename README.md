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
```
