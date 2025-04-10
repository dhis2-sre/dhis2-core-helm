# Beyond Data Platform Helm Chart

## Configuration

Ensure the `KUBECONFIG` environment variable is pointing to a valid Kubernetes configuration file.

If you don't have a cluster available, one can be created using [this](https://github.com/bombeke/im-cluster) project.


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
helm install certmanagerissuer --namespace cert-manager dhis2/certmanager --set enabled=true
```

Add the annotations to Ingress
```
 annotations:
   cert-manager.io/cluster-issuer: "le-staging"
   ...
```

## Installing DHIS2 Core Helm

[DHIS2 core helm chart](./charts/core) is published to
https://bombeke.github.io/dhis2-helm

To install the chart you first need to add this chart repository

```sh
helm repo add dhis2 https://bombeke.github.io/dhis2-helm
helm repo update
helm search repo dhis2/core --versions
```

## Installing SmartAI 
[DHIS2 smartai helm chart](./charts/smartai) is published to
https://bombeke.github.io/dhis2-helm

To update dhis2-helm chart repository

```sh
helm repo update
helm search repo dhis2/smartai --versions
helm install smart dhis2/smartai -n smart --create-namespace -f values.yaml
```
Example smart values.yaml

```yaml
origins:
 - "http://localhost:3000"
 - "localhost:3000"
 - "*"
dhis2:
 url: "https://dhis.example.com"
 username: "username"
 password: "password"
vector:
 dimension: 4096
broker:
 servers: "localhost:29092,localhost:39092,localhost:49092"
 password: "password"
 username: "username"
auth:
 auth_type: "casdoor"
 redirect_uri: "http://localhost:3000/#/auth-callback"
 real_name: "app-demo"
 server: "https://auth1.example.com"
 client_id: "94ce7d07f59820c8945f"
 client_secret: "354d4372aee1000b304a5991f75bfbfa12de6b59"
 org_name: "demo"
 application_name: "app-demo"
 certificate: "/opt/smartai/cert_public.pem"
api:
 server: "http://localhost:3000/#"
database:
 url: "localhost"
 password: "password"
```
## Installing AI/ML Inference Service
[AI/ML Inference server helm chart](./charts/tritonserver) is published to
https://bombeke.github.io/dhis2-helm

To update dhis2-helm chart repository

```sh
helm repo update
helm search repo dhis2/tritonserver --versions
```

## Installing Data Warehouse
```
starrocks:
    initPassword:
        enabled: true
        # Set a password secret, for example:
        # kubectl create secret generic starrocks-root-pass --from-literal=password='g()()dpa$$word'
        passwordSecret: starrocks-root-pass

    starrocksFESpec:
        replicas: 3
        service:
            type: LoadBalancer
        resources:
            requests:
                cpu: 1
                memory: 1Gi
        storageSpec:
            name: fe

    starrocksBeSpec:
        replicas: 3
        resources:
            requests:
                cpu: 1
                memory: 2Gi
        storageSpec:
            name: be
            storageSize: 15Gi

    starrocksFeProxySpec:
        enabled: true
        service:
            type: LoadBalancer
```
### Release a chart e.g core


The versions returned are gathered from [index.yaml](./index.yaml) which is
published to [this GitHub page](https://bombeke.github.io/dhis2-helm/index.yaml).

Bump the version in [Chart.yaml](./charts/core/Chart.yaml), commit and push.
**NOTE: do not create a tag yourself!**

Our release workflow will then using [Helm chart releaser action](https://github.com/helm/chart-releaser-action)

* create a tag `core-<version>`
* create a [release](https://github.com/bombeke/dhis2-helm/releases) associated with the new tag
* commit an updated index.yaml with the new release
* redeploy the GitHub pages to serve the new index.yaml

Note: there might be a slight delay between the release and the `index.yaml`
file being updated as GitHub pages have to be re-deployed.
