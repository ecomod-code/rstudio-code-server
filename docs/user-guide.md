# Your ecomod RStudio and VS Code environment

## Access

You use the environment through two web apps:

| App | URL |
|----|----|
| RStudio Server | `https://<your-server>/` |
| VS Code (code-server) | `https://<your-server>/code/` |

Both log in with username `rstudio` and the password you got from me. There is no other access to the machine (no SSH). Anything that has to be done on the machine itself, I do for you.

## Shared home folder for RStudio and VS Code

Both show the same files: your RStudio home folder (`/home/rstudio`) is the VS Code workspace.

R, NetLogo and InVEST are only available in RStudio. VS Code runs separately and comes with Python 3, Node.js, gcc/make and Playwright. Use it for editing, git and non-R work, and run R and NetLogo jobs from RStudio.

RStudio sessions don't time out. A long-running job keeps going after you close the browser tab, but you can't login again, until the job as finished. To avoid this just use backgroud jobs in RStudio (ask me if you don't know them).

## ⚠️ There is no backup

Nothing is backed up. If the server fails or is deleted, all your files in RStudio and VS Code are lost. Protect your work like this:

- **Nextcloud sync (optional):** the folder `~/RStudio-Server` can sync both ways with a folder of the same name in your Nextcloud, every 15 minutes. I set this up for you. Follow [Syncing your RStudio Server with Nextcloud](nextcloud-sync.md), which explains how to create the folder and an app password and send them to me. This is a sync, not a backup: a file you delete on one side is deleted on the other side too.
- **Git:** push your code to GitHub/GitLab regularly.

Everything outside `RStudio-Server` stays only on the server.

## What survives an update

I update the software from time to time. Your home folder survives updates, including R packages you installed yourself (they go to your personal library under `~/R`). If you need software that you can't install as an R package yourself (for example a system library), ask me and I'll add it for everyone.

## Preinstalled software

- **R 4.6.2** with the rocker/geospatial stack (tidyverse, sf, terra, raster, stars, GDAL/PROJ, …)
- **Extra R packages:** bench, betapart, clustermq, devtools, furrr, future, future.apply, future.batchtools, igraph, landscapemetrics, magick, microbenchmark, nlrx, plotrix, rasterVis, rcdd, Rcpp, remotes, RInside, rjags (with JAGS), rslurm, skimr, ssh, targets, usethis, vegan, withr
- **From GitHub:** Refforts (dev2.0), NLMR, landscapetools
- **Java 21**
- **InVEST 3.11.0** (Python 3.9) at `/opt/conda/envs/invest/bin/python`. To use it from R: `reticulate::use_python("/opt/conda/envs/invest/bin/python")`

## NetLogo

Three versions are installed under `/opt/netlogo/`: `6.2.1`, `6.4.0` and `7.0.4`. They run headless only; there is no NetLogo GUI. Use them from R via nlrx, for example:

```r
library(nlrx)
nl <- nl(nlversion = "6.4.0",
         nlpath    = "/opt/netlogo/6.4.0",
         modelpath = "~/my-model/model.nlogo",
         jvmmem    = 4096)
```

## NetVest (EFForTS-ABM + InVEST Habitat Quality)

NetVest is installed read-only at `/opt/NetVest`. It writes its outputs into its own folder, so you first need your own copy. Run this once in the RStudio *Terminal* tab:

```sh
mkdir -p ~/NetVest && cp -rL /opt/NetVest/. ~/NetVest/
```

Then use NetLogo **6.2.1**, the version NetVest needs, with the model `~/NetVest/EFForTS-ABM.nlogo`:

```r
nl <- nl(nlversion = "6.2.1",
         nlpath    = "/opt/netlogo/6.2.1",
         modelpath = "~/NetVest/EFForTS-ABM.nlogo",
         jvmmem    = 4096)
```

Outputs end up in `~/NetVest/output` and `~/NetVest/ncinv/habitatquality/output`.

## Questions

Questions or missing packages → just message me.
