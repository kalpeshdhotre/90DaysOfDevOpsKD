# Day 54 – Kubernetes ConfigMaps and Secrets

## What ConfigMaps and Secrets Are

**ConfigMaps** store non-sensitive configuration data as key-value pairs — things like environment names, feature flags, ports, or full config files. They decouple configuration from container images, so you can change config without rebuilding or re-pushing an image.

**Secrets** store sensitive data — passwords, API keys, tokens — in the same key-value shape as ConfigMaps, but base64-encoded and handled with tighter defaults (RBAC restrictions, tmpfs storage on nodes instead of disk, optional encryption at rest).

Use a ConfigMap when the data is fine to see in plaintext. Use a Secret when it isn't.

---

## Task 1: ConfigMap from Literals

```bash
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_DEBUG=false \
  --from-literal=APP_PORT=8080
```

```bash
kubectl describe configmap app-config
kubectl get configmap app-config -o yaml
```

The `data:` section stores everything as plain readable text — no encoding, no encryption. This is the baseline that makes the Secrets comparison in Task 4 meaningful.

![alt text](<Screenshot From 2026-07-15 18-37-56.png>)

---

## Task 2: ConfigMap from a File

Custom Nginx config with a `/health` endpoint:

```nginx
server {
    listen 80;

    location /health {
        default_type text/plain;
        return 200 "healthy\n";
    }

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
```

```bash
kubectl create configmap nginx-config --from-file=default.conf=default.conf
kubectl get configmap nginx-config -o yaml
```

The key name (`default.conf`) becomes the filename once mounted into a Pod — the whole file's content lives under that one key.

![alt text](<Screenshot From 2026-07-15 18-43-52-1.png>)

---

## Task 3: Using ConfigMaps in a Pod

**Environment variables via `envFrom`:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: envfrom-pod
spec:
  containers:
    - name: busybox
      image: busybox
      command: ["sh", "-c", "env | grep APP_ && sleep 3600"]
      envFrom:
        - configMapRef:
            name: app-config
```

**Volume mount for the full Nginx config:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-config-pod
spec:
  containers:
    - name: nginx
      image: nginx
      ports:
        - containerPort: 80
      volumeMounts:
        - name: config-volume
          mountPath: /etc/nginx/conf.d
  volumes:
    - name: config-volume
      configMap:
        name: nginx-config
```

![alt text](<Screenshot From 2026-07-15 18-59-47.png>)
Rule of thumb confirmed hands-on: environment variables for simple key-value settings, volume mounts for full config files.
![alt text](<Screenshot From 2026-07-15 18-45-27.png>)

---

## Task 4: Creating a Secret

```bash
kubectl create secret generic db-credentials \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASSWORD=s3cureP@ssw0rd
```

```bash
kubectl get secret db-credentials -o yaml
kubectl get secret db-credentials -o jsonpath='{.data.DB_PASSWORD}' | base64 --decode
```

The stored value decodes cleanly back to `s3cureP@ssw0rd` with a single `base64 --decode` — no key, no cipher, nothing to break. That's the whole point of the next section.

---

## Task 5: Using a Secret in a Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-pod
spec:
  containers:
    - name: busybox
      image: busybox
      command: ["sh", "-c", "sleep 3600"]
      env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: DB_USER
      volumeMounts:
        - name: secret-volume
          mountPath: /etc/db-credentials
          readOnly: true
  volumes:
    - name: secret-volume
      secret:
        secretName: db-credentials
```

```bash
kubectl exec secret-pod -- sh -c 'echo $DB_USER'
# admin
kubectl exec secret-pod -- cat /etc/db-credentials/DB_PASSWORD
# s3cureP@ssw0rd
```

Once inside the container, both the env var and the mounted file are plaintext. The base64 layer only exists at rest in the Secret object and in transit — Kubernetes decodes it before it ever reaches the container.

---

## Why base64 Is Encoding, Not Encryption

Encoding is a reversible transformation with no key involved — anyone can decode it, which is exactly what `base64 --decode` demonstrated in Task 4. Encryption requires a key or credential to reverse. Secrets rely on base64 purely as a safe transport format for arbitrary binary/text data inside YAML/JSON — the real protection comes from Kubernetes RBAC controlling who can `get`/`describe` the Secret object at all, Secrets living in tmpfs (memory) on nodes rather than written to disk, and optionally enabling encryption at rest on the cluster. Anyone with API access to read the Secret can trivially decode it.

![alt text](<Screenshot From 2026-07-15 19-01-16.png>)

---

## Task 6: ConfigMap Update Propagation

```bash
kubectl create configmap live-config --from-literal=message=hello
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: live-config-pod
spec:
  containers:
    - name: busybox
      image: busybox
      command: ["sh", "-c", "while true; do cat /etc/live-config/message; echo; sleep 5; done"]
      volumeMounts:
        - name: live-volume
          mountPath: /etc/live-config
  volumes:
    - name: live-volume
      configMap:
        name: live-config
```

```bash
kubectl patch configmap live-config --type merge -p '{"data":{"message":"world"}}'
```

Watching `kubectl logs -f live-config-pod`, the printed value flipped from `hello` to `world` within roughly 30-60 seconds — with zero pod restarts. The kubelet periodically re-syncs mounted ConfigMap/Secret volumes on the node, so the file content updates in place.

![alt text](<Screenshot From 2026-07-15 19-07-04.png>)

**Environment variables behave differently.** They're resolved once, at container start, and frozen from then on — patching the source ConfigMap afterward has no effect on an already-running container. Confirmed this two ways during testing: the `app-config` env var pod kept its original values after a patch, and separately, patching a _key that didn't exist yet_ via `kubectl patch --type merge` simply added it as a new key in the ConfigMap rather than updating anything — since a running pod's `envFrom` had already locked in its environment at creation, the new key was invisible to it until the pod was deleted and recreated.

**Takeaway:** if you need config changes to reach a running app without a restart, volume mounts are the mechanism — env vars require a pod restart (or at minimum a re-read on the next scheduling event) to pick up new values.

---

## Task 7: Clean Up

```bash
kubectl delete pod envfrom-pod nginx-config-pod secret-pod live-config-pod
kubectl delete configmap app-config nginx-config live-config
kubectl delete secret db-credentials
kubectl get pods,configmaps,secrets
```

All resources removed, confirmed with a final `get`.

## ![alt text](<Screenshot From 2026-07-15 19-22-22.png>)

**#90DaysOfDevOps #DevOpsKaJosh #TrainWithShubham**
