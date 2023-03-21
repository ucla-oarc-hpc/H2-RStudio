# RStudio on Hoffman2

Easily run RStudio on Hoffman2 (H2) compute nodes using available containers.

## Available RStudio Containers

Find available RStudio containers on Hoffman2 with the following command:

```
module load apptainer
ls $H2_CONTAINER_LOC/h2-rstudio*sif
```


To create your own RStudio container or use a different version, visit the [UCLA OARC HPC Containers repository](https://github.com/ucla-oarc-hpc/hpc_containers).

## RStudio Workshop

For more information on using RStudio on Hoffman2, visit the [H2HH RStudio Workshop](https://github.com/ucla-oarc-hpc/H2HH_rstudio).

## Running RStudio: Step-by-Step Guide

Follow these steps to run RStudio using an RStudio container on Hoffman2:

1. **Request an interactive job**:

   RStudio and Apptainer can only run on a compute node, not on a login node.

```
qrsh -l h_data=10G
```

2. **Create temporary directories**:

RStudio needs these directories to run correctly. Create them in your `$SCRATCH` directory.

```
mkdir -pv $SCRATCH/rstudiotmp/var/lib
mkdir -pv $SCRATCH/rstudiotmp/var/run
mkdir -pv $SCRATCH/rstudiotmp/tmp
```

3. **Load Apptainer module**:

```
module load apptainer
```

4. **Start RStudio process**:

Do not kill this process until you are finished with RStudio.

```
apptainer run \
      -B $SCRATCH/rstudiotmp/var/lib:/var/lib/rstudio-server \
      -B $SCRATCH/rstudiotmp/var/run:/var/run/rstudio-server \
      -B $SCRATCH/rstudiotmp/tmp:/tmp \
         $H2_CONTAINER_LOC/h2-rstudio_4.1.0.sif
```

This will display information and an `ssh -L ...` command to run in a separate terminal.

5. **Connect to the compute node's port**:

Open a new terminal and run the provided `ssh -L ...` command.

```
ssh  -L 8787:nXXX:8787 username@hoffman2.idre.ucla.edu # Or whatever command was displayed earlier 
```


6. **Access RStudio in your web browser**:

Enter the following URL in your web browser:

```
http://localhost:8787 #or whatever port number that was displayed
```


When finished, exit RStudio and press `[Ctrl-C]` in the terminal running the RStudio container to exit the job.

## Running RStudio: Automated Script

Use the `h2_rstudio.sh` script on your local machine to automatically set up RStudio on Hoffman2.

1. **Display usage statement**:

```
./h2_rstudio.sh -h
```

2. **Start RStudio on Hoffman2**:

```
./h2_rstudio.sh -u H2USERNAME
```


This will start RStudio as a `qrsh` job, open a port tunnel, and allow you to access RStudio in your web browser.

**Note**: This script has been tested on Mac's Terminal, Windows WSL2, and Mobaxterm. It will fail on GitBash due to the lack of the `expect` command.

## Running R in Batch Mode

If you want to use the R version in the container for a batch job, use the `rstudio_batch.job` script. This example SGE job script submits an R job using the R version inside the RStudio container and uses the installed libraries. This is helpful if you have installed packages with RStudio and want to run an R batch job with the same version of R and R packages.

## Troubleshooting Common Issues

If a new RStudio session doesn't start correctly (e.g., due to an improper exit), try the following:

1. **Remove RStudio temporary directories**:

```
rm -rf $SCRATCH/rstudiotmp
```

2. **Clear RStudio config files**:

```
rm -rf ~/.config/rstudio
```

By following these guidelines and solutions, you should be able to easily run RStudio on Hoffman2 compute nodes and troubleshoot any common issues that may arise.



