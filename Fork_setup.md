NASTAVI FORK: pull original repo, push moj fork

## 1) Preveril sem trenutni remote (`origin`)

```bash
git remote -v
```

Izpis:

```text
origin  https://github.com/Student-na-praksi/HPC.git (fetch)
origin  https://github.com/Student-na-praksi/HPC.git (push)
```

## 2) Če ročno poganjaš sinhronizacijo forka: Dodaj `upstream` (original/profesorjev repo)

```bash
git remote add upstream https://github.com/laspp/HPC.git
git remote -v
```

Pričakovani izpis po dodanem `upstream`:

```text
origin    https://github.com/Student-na-praksi/HPC.git (fetch)
origin    https://github.com/Student-na-praksi/HPC.git (push)
upstream  https://github.com/laspp/HPC.git (fetch)
upstream  https://github.com/laspp/HPC.git (push)
```

## 3) Nastavil sem dnevni sync forka na GitHubu

Datoteka: `.github/workflows/sync-fork.yml`

Kaj je nastavljeno:

- Ime workflowa: `Sync fork from laspp/HPC`.
- Trigger:
	- dnevno preko `cron: "0 4 * * *"` (04:00 UTC),
	- ročni zagon preko `workflow_dispatch`.
- Dovoljenja: `contents: write` (da lahko action push-a spremembe).
- Job teče na `ubuntu-latest`.
- Checkout z `fetch-depth: 0` (celotna zgodovina).
- Environment spremenljivke:
	- `UPSTREAM_REPO: laspp/HPC`
	- `UPSTREAM_BRANCH: main`
	- `FORK_BRANCH: main`
- Sync koraki v skripti:
	- doda remote `upstream`,
	- `git fetch upstream main`,
	- `git checkout main`,
	- `git merge --ff-only upstream/main` (varen fast-forward sync),
	- `git push origin main`.

## 4) Rezultat

Update flow je uspešno nastavljen:

- profesorjeve spremembe prihajajo v fork preko GitHub Actions,
- lokalno potem običajno zadostuje `git pull origin main`,
- svoje delo pusham na svoj fork (`origin`).

