# DHIS2 Core Helm Chart

## Configuration

Ensure the `KUBECONFIG` environment variable is pointing to a valid Kubernetes configuration file.

If you don't have a cluster available, one can be created using [this](https://github.com/dhis2-sre/im-cluster) project.

## Launch

```bash
skaffold dev
```

## Helm

### Package

> NOTE: Remember to bump the chart version specified in [Chart.yaml](./Chart.yaml)

```bash
helm package .
```

### Post to repository

```bash
curl --user "$CHARTMUSEUM_AUTH_USER:$CHARTMUSEUM_AUTH_PASS" \
        -F "chart=@dhis2-core-0.5.0.tgz" \
        https://helm-charts.fitfit.dk/api/charts
```
