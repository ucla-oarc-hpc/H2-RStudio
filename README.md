# Rstudio on Hoffman2

Hoffman2 has the ability to run RStudio on the H2 compute nodes. 

Hoffman2 has a RStudio containers that can be ran using Apptainer that can be run on a compute node and rendered on the user's local machine

The available RStudio containers on Hoffman2 can be found at

```
ls $H2_CONTAINER_LOC/h2-rstudio*sif
```

You can also create your own RStudio containers if you want different versions or install more applications inside the container. The Dockerfiles used to create the RStudio containers on Hoffman2 are located at `https://github.com/ucla-oarc-hpc/hpc_containers`
 
We have a workshop on using RStudio on Hoffman2 for more information

https://github.com/ucla-oarc-hpc/H2HH_rstudio


## Running Rstudio - the long way

Users can follow these steps in order to run Rstudio using the Rstudio container on Hoffman2


1. Get an interactive job

RStudio, and Apptainer in general, can **ONLY** be ran on a compute node. You cannot run this on a login node.

```
qrsh -l h_data=10G
```

2. Create tmp directories

RStudio requires to write small files in order to run correctly. You can create this files in your $SCRATCH directory so they can be bind mounted to the container.

```
mkdir -pv $SCRATCH/rstudiotmp/var/lib
mkdir -pv $SCRATCH/rstudiotmp/var/run
mkdir -pv $SCRATCH/rstudiotmp/tmp
```

3. Setup apptainer

```
module load apptainer/1.0.0
```

4. Run rstudio

This will start a the RStudio process. Do **NOT** kill this process until you are finish with RStudio.

This example uses the RStudio container 
```
apptainer run \
      -B $SCRATCH/rstudiotmp/var/lib:/var/lib/rstudio-server \
      -B $SCRATCH/rstudiotmp/var/run:/var/run/rstudio-server \
      -B $SCRATCH/rstudiotmp/tmp:/tmp \
         $H2_CONTAINER_LOC/h2-rstudio_4.1.0.sif
```

This will display some information and a `ssh -L ...` command for you to run on a separate terminal 

This example uses the Rstudio container located at `$H2_CONTAINER_LOC/h2-rstudio_4.1.0.sif`. You can replace this will any RStudio container we have or create your own. Running `ls $H2_CONTAINER_LOC/h2-rstudio*` will display all the RStudio container we currectly have.


5. Open a new terminal and connect to the compute node's port on Hoffman2 running RStudio. 

```
ssh  -L 8787:nXXX:8787 username@hoffman2.idre.ucla.edu # Or whatever command was displayed earlier 
```

6. Then open a web browser and type

```
http://localhost:8787 #or whatever port number that was displayed
```

Then you can use Rstudio on your web browser. When you are done, it is best to exit Rstudio and press [Crtl-C] to the terminal running the Rstudio container to exit the job.

## Running Rstudio - the easy way

We have built a script to automatically setup Rstudio server on a compute node on Hoffman2.
 
Users can run the `h2_rstudio.sh` script on their local machine to setup RSudio.

```
./h2_rstudio.sh -h
```

This will give you a usage statment on running the Hoffman2 RStudio script.

```
./h2_rstudio.sh -u H2USERNAME
```

This is start RStudio on hoffman2 as a qrsh job and open a port tunnel to the Hoffman2 compute node. Then you came open a web browser to set RStudio.

---
**NOTE**

This script has been test on Mac's terminal, Windows WSL2, and Mobaxterm. This script will fail on GitBash because it doesn't have the `execpt` command.
 
---


## Running R in BATCH mode

The version of R in this container is installed in the container. If you want to continue using this version of R in a Batch job, instead of an interactive Rstudio, you will need run R inside the container.

The job script `rstudio_batch.job` is an example of a SGE job script that will submit a R job using the version of R inside of the Rstudio container and use the libraries that were installed using this version.

This is great if you used and installed packages with Rstudio and you want to run a R batch job with the same version of R and R packages.


## Common Issues

Sometimes if RStudio was not exited correctly, a new RStudio session may not start correctly. If this happen you can try

- removing the RStudio tmp directories

```
rm -rf $SCRATCH/rstudiotmp
```

- clearing out the rstudio config files

```
rm -rf ~/.config/rstudio
```


