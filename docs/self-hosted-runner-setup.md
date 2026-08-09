# GitHub Self-Hosted Runner Setup for Local Harbor

Use a self-hosted GitHub Actions runner when the workflow must push images to
the Harbor registry running on this laptop at `vharbor.aliien.uk`.

> Security: use a self-hosted runner only with a trusted private repository.
> Workflow code executes directly on the runner machine.

## 1. Create the runner in GitHub

Open the repository in GitHub and go to:

```text
Settings → Actions → Runners → New self-hosted runner
```

Select:

- Operating system: Linux
- Architecture: x64

GitHub displays version-specific download and extraction commands. Run those
exact commands on this laptop. Install the runner in a dedicated directory,
for example:

```bash
mkdir -p ~/actions-runner
cd ~/actions-runner
```

Do not copy a registration token into this repository. Tokens shown on the
GitHub Runners page are temporary.

## 2. Register the runner

From `~/actions-runner`, run the command supplied by GitHub. The default
`self-hosted`, `Linux`, and `X64` labels are sufficient:

```bash
./config.sh \
  --url https://github.com/LubnaIbrahimMU/imagine-local-stack \
  --token TOKEN_FROM_GITHUB \
  --name mypro-harbor-runner
```

Use the real temporary token shown by GitHub in place of
`TOKEN_FROM_GITHUB`.

## 3. Test the runner interactively

```bash
cd ~/actions-runner
./run.sh
```

The runner is ready when the terminal displays:

```text
Connected to GitHub
Listening for Jobs
```

Verify that GitHub shows `mypro-harbor-runner` as `Idle` under:

```text
Settings → Actions → Runners
```

Press `Ctrl+C` before installing it as a service.

## 4. Allow the runner user to use Docker

```bash
sudo usermod -aG docker lu
```

Log out and back in if `lu` was not already a member of the Docker group.
Confirm access without `sudo`:

```bash
docker version
```

## 5. Install the runner as a system service

Install the service under user `lu` so it can use that user's Docker and
Kubernetes configuration:

```bash
cd ~/actions-runner
sudo ./svc.sh install lu
sudo ./svc.sh start
sudo ./svc.sh status
```

Useful service commands:

```bash
sudo ./svc.sh stop
sudo ./svc.sh start
sudo ./svc.sh status
```

After a reboot, confirm that the service and runner are online.

## 6. Verify required tools and local services

Run these commands as user `lu`:

```bash
docker version
kubectl cluster-info
helm version
getent hosts vharbor.aliien.uk
curl -k https://vharbor.aliien.uk/api/v2.0/health
```

Also confirm that Docker can authenticate to Harbor:

```bash
docker login vharbor.aliien.uk
```

If Docker reports an unknown certificate authority, rerun the repository's
Harbor trust setup and restart the runner service:

```bash
sudo ./scripts/setup-docker-harbor-trust.sh
cd ~/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh start
```

## 7. Configure GitHub Actions secrets

Open:

```text
Settings → Secrets and variables → Actions
```

Create these repository secrets:

```text
HARBOR_USERNAME
HARBOR_PASSWORD
```

Never commit Harbor credentials to the workflow or repository.

## 8. Configure workflow runner labels

Keep validation and GitOps commit jobs on GitHub-hosted runners. Run only the
private Harbor job on this laptop:

```yaml
lint-and-validate:
  runs-on: ubuntu-latest

build-and-push-harbor:
  runs-on: [self-hosted, Linux, X64]

update-gitops-and-sync-argo:
  runs-on: ubuntu-latest
```

Every label in `runs-on` must be present on the runner. GitHub will leave the
job waiting when no online, idle runner matches all labels.

## 9. Run and verify the pipeline

Commit and push the workflow change, then open the Actions page. Cancel any
old waiting workflow and start a new run.

Expected sequence:

1. `Lint & Validate Code` runs on `ubuntu-latest`.
2. `Harbor Container Registry Sync` runs on `mypro-harbor-runner`.
3. Images are pushed using the triggering `${{ github.sha }}` tag.
4. `Update Helm Image Tags for Argo CD GitOps` writes the same tag.
5. The workflow rebuilds the umbrella Helm dependencies.
6. The workflow commits and pushes the GitOps change.
7. Argo CD detects and synchronizes the new revision.

Verify the resulting workloads:

```bash
kubectl get applications -n argocd
kubectl get pods -n dev
```

## Troubleshooting

### Workflow says `Waiting for a runner to pick up this job`

```bash
cd ~/actions-runner
sudo ./svc.sh status
sudo ./svc.sh start
```

Confirm the runner is online and has all three labels:

```text
self-hosted, Linux, X64
```

### Runner is online but does not accept the job

- Confirm it is `Idle`, not already running another job.
- Confirm the workflow and runner labels match exactly.
- Confirm the runner belongs to this repository or an allowed runner group.
- Cancel the old run and start a new run after changing labels.

### Docker permission denied

```bash
sudo usermod -aG docker lu
```

Log out and back in, then restart the runner service.

### Harbor login or push fails

Check:

```bash
getent hosts vharbor.aliien.uk
curl -k https://vharbor.aliien.uk/api/v2.0/health
docker login vharbor.aliien.uk
```

Then verify that `HARBOR_USERNAME` and `HARBOR_PASSWORD` are configured in
GitHub Actions secrets.

## Official documentation

- [Adding self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners)
- [Running the runner as a service](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/configure-the-application?platform=linux)
- [Using self-hosted runner labels](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/apply-labels)
