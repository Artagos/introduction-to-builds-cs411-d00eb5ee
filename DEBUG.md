# DEBUG.md

## ImagePullBackOff — Root Cause Analysis

---

## Hypotheses (ranked by likelihood)

**1. The cluster nodes lack credentials to pull from `ttl.sh`**

`ttl.sh` is a public registry, but the Pod is running in a cluster whose nodes (or service account) have no `imagePullSecret` configured, so the kubelet's pull attempt is rejected or rate-limited in a way that `docker pull` on the Jenkins machine — which may have cached credentials or a Docker login — does not trigger.

**2. The image tag has already expired on `ttl.sh`**

`ttl.sh` images expire after a short TTL (as short as 1–24 h); the pipeline pushed the image successfully and Jenkins can still pull it from a local cache or within the TTL window, but by the time the cluster tries to pull, the tag no longer exists on the registry.

---

## Verification steps

**Hypothesis 1 — missing pull credentials:**
```bash
kubectl describe pod <pod-name> | grep -A 10 "Events:"
```
Look for `401 Unauthorized` or `no basic auth credentials` in the event log. If the error message references authentication rather than "not found", credentials are the problem.

**Hypothesis 2 — expired / missing tag:**
```bash
curl -s https://ttl.sh/v2/<your-image>/manifests/<your-tag> \
  -o /dev/null -w "%{http_code}"
```
A `404` or `401` response from the registry API confirms the tag is gone (or never landed). You can cross-check with `kubectl describe pod` looking for `manifest unknown` or `not found` in the pull error.

---

## Fix

**If hypothesis 1 (auth):** create an `imagePullSecret` pointing at `ttl.sh` and attach it to the Pod:

```bash
kubectl create secret docker-registry ttlsh-pull-secret \
  --docker-server=ttl.sh \
  --docker-username=<user> \
  --docker-password=<token> \
  --docker-email=<email>
```

Then add to the Pod manifest (minimal diff — only the `imagePullSecrets` stanza):

```yaml
spec:
  imagePullSecrets:
    - name: ttlsh-pull-secret
  containers:
    - name: myapp
      image: ttl.sh/<your-image>:<your-tag>
```

**If hypothesis 2 (expired tag):** re-run the pipeline to push a fresh image with a new tag (or a longer TTL), then patch the Pod to use the new tag:

```bash
kubectl set image pod/<pod-name> myapp=ttl.sh/<your-image>:<new-tag>
```

---

## Underlying lesson

"I can pull this image" means *your* Docker client, with *your* credentials and cache, can reach the registry — but "the cluster can pull this image" means the **kubelet on each node** must be able to reach the same registry URL, authenticate with its own credentials (or an `imagePullSecret`), and find a tag that still exists at pull time; those are three independent conditions that your local environment silently satisfies but the cluster does not inherit.