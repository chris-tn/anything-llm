# AnythingLLM Helm Chart

This chart deploys AnythingLLM (server + collector) based on the reference Kubernetes manifest in `cloud-deployments/k8/manifest.yaml`.

## Quickstart

- Create a namespace (optional):

```sh
kubectl create namespace anything-llm
```

- Create a `values.yaml` with your overrides (domain, secrets, etc.):

```yaml
ingress:
  host: "your-namespace-chat.example.com"

secrets:
  create: true
  awsAccessKeyId: "AKIA..."
  awsSecretAccessKey: "..."
  jwtSecret: "change-me-to-random"

env:
  AWS_REGION: "us-east-1"
```

- Install:

```sh
helm install anything-llm cloud-deployments/helm/anything-llm -n anything-llm -f my-values.yaml
```

## Notes
- By default, a `PersistentVolumeClaim` is created. If you have a pre-provisioned EBS volume, set `persistence.ebsVolumeId` to create a static `PersistentVolume` bound to the claim.
- Probes, resources, security context, node affinity, and ingress are configurable via `values.yaml`.
- The chart runs the server and collector processes in the same container as in the provided manifest.
