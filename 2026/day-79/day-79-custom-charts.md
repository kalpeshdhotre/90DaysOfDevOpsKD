# Day 79 — Creating a Custom Helm Chart for AI-BankApp

Converted the AI-BankApp's 12 raw Kubernetes manifests (`k8s/`) into a fully templated, configurable Helm chart — deployable with a single `helm install`.

---

## 1. Raw Manifests vs Helm Templates

### `k8s/secrets.yml` → `templates/secrets.yaml`

**Before (raw manifest):**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bankapp-secret
type: Opaque
data:
  MYSQL_ROOT_PASSWORD: VGVzdEAxMjM= # manually base64-encoded
  MYSQL_USER: cm9vdA==
  MYSQL_PASSWORD: VGVzdEAxMjM=
```

**After (Helm template):**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "bankapp.fullname" . }}-secret
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "bankapp.labels" . | nindent 4 }}
type: Opaque
data:
  MYSQL_ROOT_PASSWORD: {{ .Values.secrets.mysqlRootPassword | b64enc | quote }}
  MYSQL_USER: {{ .Values.secrets.mysqlUser | b64enc | quote }}
  MYSQL_PASSWORD: {{ .Values.secrets.mysqlPassword | b64enc | quote }}
```

No more manual `base64` encoding — `b64enc` handles it, and credentials are overridable per environment via `values.yaml` or `--set`.

### `k8s/ollama-deployment.yml` → `templates/ollama-deployment.yaml`

**Before:** model name (`tinyllama`) and resource limits hardcoded directly in the manifest.

**After:**

```yaml
{{- if .Values.ollama.enabled }}
...
          image: "{{ .Values.ollama.image.repository }}:{{ .Values.ollama.image.tag }}"
          {{- with .Values.ollama.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          lifecycle:
            postStart:
              exec:
                command:
                  - /bin/sh
                  - -c
                  - |
                    until ollama list > /dev/null 2>&1; do sleep 2; done
                    ollama pull {{ .Values.ollama.model }}
{{- end }}
```

Wrapping the whole block in `{{- if .Values.ollama.enabled }}` means the AI chatbot component — Deployment, Service, PVC, and the BankApp init container that depends on it — can be switched off entirely with one flag.

### `k8s/pv.yml` + `k8s/pvc.yml` → `templates/storage.yaml`

**Before:** two separate static files, storage class and sizes hardcoded.

**After:** one template, StorageClass creation and both PVCs gated by values:

```yaml
{{- if .Values.storageClass.create }}
apiVersion: storage.k8s.io/v1
kind: StorageClass
...
{{- end }}
---
{{- if .Values.mysql.enabled }}
...
  storageClassName: {{ .Values.mysql.persistence.storageClass }}
  resources:
    requests:
      storage: {{ .Values.mysql.persistence.size }}
{{- end }}
```

On Kind, `storageClass.create=false` and `storageClass: standard` overrides let the same chart run without AWS EBS.

---

## 2. Complete `values.yaml`

```yaml
bankapp:
  replicaCount: 4
  image:
    repository: trainwithshubham/ai-bankapp-eks
    tag: "latest"
    pullPolicy: Always
  resources:
    requests: { memory: "256Mi", cpu: "250m" }
    limits: { memory: "512Mi", cpu: "500m" }
  service:
    type: ClusterIP
    port: 8080
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 4
    targetCPUUtilization: 70

mysql:
  enabled: true
  image: { repository: mysql, tag: "8.0" }
  resources:
    requests: { memory: "256Mi", cpu: "250m" }
    limits: { memory: "512Mi", cpu: "500m" }
  persistence: { size: 5Gi, storageClass: gp3 }

ollama:
  enabled: true
  image: { repository: ollama/ollama, tag: "latest" }
  model: tinyllama
  resources:
    requests: { memory: "2Gi", cpu: "900m" }
    limits: { memory: "2.5Gi", cpu: "1500m" }
  persistence: { size: 10Gi, storageClass: gp3 }

config:
  mysqlDatabase: bankappdb
  ollamaUrl: "" # auto-derived from service name when empty

secrets:
  mysqlRootPassword: Test@123
  mysqlUser: root
  mysqlPassword: Test@123

storageClass:
  create: true
  name: gp3
  provisioner: ebs.csi.aws.com

gateway:
  enabled: false
  hostname: ""
  tls: { enabled: false }
```

| Key                                | Purpose                                                                         |
| ---------------------------------- | ------------------------------------------------------------------------------- |
| `bankapp.autoscaling.*`            | Drives the HPA — enable/disable and tune min/max replicas + CPU target          |
| `mysql.enabled` / `ollama.enabled` | Toggle entire components (Deployment + Service + PVC) on or off                 |
| `secrets.*`                        | Base64-encoded automatically via `b64enc` — no manual encoding                  |
| `storageClass.create`              | Set `false` on clusters (like Kind) that already provide a default StorageClass |
| `gateway.*`                        | Optional Envoy Gateway + TLS config for EKS; left disabled locally              |

---

## 3. Go Template Syntax Cheat Sheet

| Syntax                                   | What it does                                                                                   |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `{{ .Values.x }}`                        | Reads a value from `values.yaml`                                                               |
| `{{- if cond }} ... {{- end }}`          | Conditionally includes a block (used for `mysql.enabled`, `ollama.enabled`, `gateway.enabled`) |
| `{{ range .Values.list }} ... {{ end }}` | Loops over a list/map                                                                          |
| `{{- with .Values.x }} ... {{- end }}`   | Scopes `.` to `.Values.x` for the block, skips block entirely if `x` is empty                  |
| `{{ include "name" . }}`                 | Calls a named template (e.g. `_helpers.tpl`) and returns a string — pipeable                   |
| `{{ template "name" . }}`                | Streams a named template directly — not pipeable                                               |
| `{{ toYaml . \| nindent 12 }}`           | Converts a values object to YAML, indented to match surrounding structure                      |
| `{{ .val \| b64enc \| quote }}`          | Pipes a value through base64 encoding then quotes it                                           |
| `{{-` / `-}}`                            | Trims leading/trailing whitespace — keeps rendered YAML clean                                  |

---

## 4. `helm template` Output

Ran:

```bash
helm template my-bankapp bankapp/
```

Every `{{ }}` placeholder resolved to a concrete value — ConfigMap, Secret, StorageClass, both PVCs, all three Deployments (with init containers/probes/lifecycle hooks intact), all Services, and the HPA rendered correctly with no template errors.

## ![alt text](<md-screenshots/Screenshot From 2026-09-07 18-41-34.png>)

## 5. Deployment on Kind

```bash
helm install my-bankapp bankapp/ \
  -n bankapp --create-namespace \
  --set storageClass.create=false \
  --set mysql.persistence.storageClass=standard \
  --set ollama.persistence.storageClass=standard
```

Verified:

```bash
kubectl get all -n bankapp
kubectl get pvc -n bankapp
kubectl get configmap,secret -n bankapp
kubectl get pods -n bankapp -w
```

All resources came up: `my-bankapp-mysql` ready first, `my-bankapp-ollama` after the image pull + `tinyllama` model pull via `postStart`, then both `my-bankapp` replicas passed their init containers once MySQL/Ollama were reachable. HPA showed `2/2` replicas with CPU target `70%`.

![alt text](<md-screenshots/Screenshot From 2026-09-07 18-52-33.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-07 19-04-09.png>)
![alt text](<md-screenshots/Screenshot From 2026-09-07 19-04-47.png>)

Accessed the app:

```bash
kubectl port-forward svc/my-bankapp-service -n bankapp 8080:8080
```

Opened `http://localhost:8080` — AI-BankApp login page loaded successfully.

![alt text](<md-screenshots/Screenshot From 2026-09-07 19-06-28.png>)

---

## 6. Disabling Ollama

```bash
helm template my-bankapp bankapp/ --set ollama.enabled=false
```

With this flag, the rendered output drops:

- `Deployment/my-bankapp-ollama`
- `Service/my-bankapp-ollama`
- `PersistentVolumeClaim/my-bankapp-ollama-pvc`
- The Ollama-dependent init container inside the BankApp Deployment

One boolean removes an entire application component cleanly — no leftover orphaned resources, no manual cleanup.

---

## Summary

12 raw, static YAML files became one versioned, configurable Helm chart. Credentials, replica counts, resource limits, storage classes, and entire optional components (MySQL, Ollama) are now all controlled through `values.yaml` or `--set` overrides — with `helm lint` and `helm template` catching mistakes before anything touches the cluster.

---

## LinkedIn Post

Converted the AI-BankApp's 12 raw Kubernetes manifests into a single Helm chart today. Three deployments (Spring Boot, MySQL, Ollama AI), services, secrets, PVCs, and HPA — all templated and configurable through values.yaml. One command deploys the entire stack. One boolean disables the AI chatbot. This is what production packaging looks like.

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`
