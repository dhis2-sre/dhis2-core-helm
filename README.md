# DHIS2 Core Helm Chart

## Configuration

Ensure the `KUBECONFIG` environment variable is pointing to a valid Kubernetes configuration file.

If you don't have a cluster available, one can be created using [this](https://github.com/dhis2-sre/im-cluster) project.

## Launch

```bash
skaffold dev
```

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

Note: there might be a slight delay between the release and the `index.yaml`
file being updated as GitHub pages have to be re-deployed.

### Package

> NOTE: Remember to bump the chart version specified in [Chart.yaml](./charts/core/Chart.yaml)

```bash
helm package .
```

### Post to repository

```bash
curl --user "$CHARTMUSEUM_AUTH_USER:$CHARTMUSEUM_AUTH_PASS" \
        -F "chart=@dhis2-core-0.6.0.tgz" \
        https://helm-charts.fitfit.dk/api/charts
```
