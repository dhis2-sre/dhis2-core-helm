# DHIS2 Extended Dashboard Helm Chart

## Configuration

Ensure the `KUBECONFIG` environment variable is pointing to a valid Kubernetes configuration file.

If you don't have a cluster available, one can be created using [this](https://github.com/bombeke/im-cluster) project.


## Installing DHIS2 Core Helm

[DHIS2 core helm chart](./charts/core) is published to
https://bombeke.github.io/dhis2-helm

To install the chart you first need to add this chart repository

```sh
helm repo add dhis2 https://bombeke.github.io/dhis2-helm
helm repo update
helm search repo dhis2/core --versions
```

The versions returned are gathered from [index.yaml](./index.yaml) which is
published to [this GitHub page](https://bombeke.github.io/dhis2-helm/index.yaml).

## Installing CertManager
Add repository and install chart
```sh
helm repo add jetstack https://charts.jetstack.io --force-update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.16.1 \
  --set crds.enabled=true
```
Deploy the certificate Issuer
```sh
helm upgrade cert-manager --namespace cert-manager dhis2/certmanager --set enabled=true
```

Add the annotations to Ingress
```
 annotations:
   cert-manager.io/cluster-issuer: "le-staging"
   ...
```
### Release a chart e.g core

Bump the version in [Chart.yaml](./charts/core/Chart.yaml), commit and push.
**NOTE: do not create a tag yourself!**

Our release workflow will then using [Helm chart releaser action](https://github.com/helm/chart-releaser-action)

* create a tag `core-<version>`
* create a [release](https://github.com/bombeke/dhis2-helm/releases) associated with the new tag
* commit an updated index.yaml with the new release
* redeploy the GitHub pages to serve the new index.yaml

Note: there might be a slight delay between the release and the `index.yaml`
file being updated as GitHub pages have to be re-deployed.
