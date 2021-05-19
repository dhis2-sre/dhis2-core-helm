# DHIS2 Core Helm Chart

## Package
```bash
helm package --sign --key 'helm' --keyring ~/.gnupg/pubring.gpg .
```

## Post to repository
```bash
curl --user "$CHARTMUSEUM_AUTH_USER:$CHARTMUSEUM_AUTH_PASS" \
        -F "chart=@dhis2-core-0.1.0.tgz" \
        -F "prov=@dhis2-core-0.1.0.tgz.prov" \
        https://helm-charts.fitfit.dk/api/charts
```
