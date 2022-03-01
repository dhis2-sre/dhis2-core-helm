# DHIS2 Core Helm Chart

## Launch

```bash
skaffold dev
```

## Helm

### Package

```bash
helm package .
```

### Post to repository

```bash
curl --user "$CHARTMUSEUM_AUTH_USER:$CHARTMUSEUM_AUTH_PASS" \
        -F "chart=@dhis2-core-0.2.0.tgz" \
        -F "prov=@dhis2-core-0.2.0.tgz.prov" \
        https://helm-charts.fitfit.dk/api/charts
```
