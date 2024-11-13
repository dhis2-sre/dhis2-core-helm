# DHIS2 Core Helm Chart

## Configuration

Ensure the `KUBECONFIG` environment variable is pointing to a valid Kubernetes configuration file.

If you don't have a cluster available, one can be created using [this](https://github.com/dhis2-sre/im-cluster) project.

## Launch

```bash
skaffold dev
```

## Launch with MinIO
* Uncomment the minio section in dhis2.yaml
* Uncomment the minio section in skaffold.yaml

## Helm

[DHIS2 core helm chart](./charts/core) is published to
https://dhis2-sre.github.io/dhis2-core-helm

To install the chart you first need to add this chart repository

```sh
helm repo add dhis2 https://dhis2-sre.github.io/dhis2-core-helm
helm repo update
helm search repo dhis2/core --versions
```

The versions returned are gathered from [index.yaml](./index.yaml) which is
published to [this GitHub page](https://dhis2-sre.github.io/dhis2-core-helm/index.yaml).

### Release

Bump the version in [Chart.yaml](./charts/core/Chart.yaml), commit and push.
**NOTE: do not create a tag yourself!**

Our release workflow will then using [Helm chart releaser action](https://github.com/helm/chart-releaser-action)

* create a tag `core-<version>`
* create a [release](https://github.com/dhis2-sre/dhis2-core-helm/releases) associated with the new tag
* commit an updated index.yaml with the new release
* redeploy the GitHub pages to serve the new index.yaml

Note: there might be a slight delay between the release and the `index.yaml`
file being updated as GitHub pages have to be re-deployed.
