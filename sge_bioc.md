---
title: "Using SGE with the BioC AMI"
author: "Dan Tenenbaum"
date: "June 16, 2014"
output: html_document
---

# Installing StarCluster

```
sudo pip install StarCluster
```

You should probably have the aws command line tools too, though it's not absolutely
necessary for this:

```
sudo pip install awscli
```


Then generate a starcluster config file by entering the command

```
starcluster help
```

This will prompt you to create a starcluster config file (choose option 2 to create it).


Then edit `~/.starcluster/config`.

## Editing the config file

In the `[aws info]` section, fill in the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` values.
If you don't have these, log into
[https://bioconductor.signin.aws.amazon.com/console](https://bioconductor.signin.aws.amazon.com/console)
and then go to
[https://console.aws.amazon.com/iam/home?region=us-east-1#users](https://console.aws.amazon.com/iam/home?region=us-east-1#users)

Scroll down to your username and click it, then click Security Credentials and Manage Access Keys.

For `AWS_USER_ID`, put 555219204010.


If you have set up an EC2 keypair before, put its name and path in the "Defining EC2 Keypairs" section,
or follow the instructions for creating a new keypair.

You can change `NODE_INSTANCE_TYPE` if you want.
More info on types is [here](https://aws.amazon.com/ec2/instance-types/).

In the "Defining EC2 Keypairs" section, change two things:

In the line `[key mykey]`, change `mykey` to the name of your keypair (the name you assigned it 
when adding it to AWS).
Change the value of `KEY_LOCATION` to the path to the private key for this keypair.
It might be something like: `~/.ec2/mykeypairname.pem`.


In the `[cluster smallcluster]` section, change `CLUSTER_SIZE` to whatever you want.
Change `NODE_IMAGE_ID` to  ami-4e817f26 for BioC 2.14, or ami-12817f7a for BioC 3.0.
These IDs are subject to change. These AMIs are not public yet but after they are,
the latest ID will be available via the AMI page on the website. 

Change the value of `KEYNAME` to the name of the keypair you'll be using (the
name you gave the keypair when you added it to AWS).

## Using the cluster with RStudio

If you want to use RStudio on the master node, add the following to the starcluster config
file in the "Configuring Security Group Permissions" section:

```
# open port 8787 on the cluster to the world
[permission rstudio]
IP_PROTOCOL = tcp
FROM_PORT = 8787
TO_PORT = 8787
```

Then in the `[cluster smallcluster]` section, add this line:

```
permissions = rstudio
```

## Starting the cluster

You can now start the cluster with the command:

```
starcluster start smallcluster
```

After a while, it will come up.

Note that it says "Installing Sun Grid Engine" during this process. This is puzzling because I
started from a StarCluster AMI that I figured would already have SGE installed, but it doesn't,
apparently. I tried uncommenting "#DISABLE_QUEUE=True" in the config and ended up with a cluster
where SGE was not installed.

Now you can ssh to the master node with

```
starcluster sshmaster --user=ubuntu smallcluster
```


Or if RStudio is set up, you can get the master node's DNS name with:

```
starcluster listclusters
```

This will give you something like:

```
-----------------------------------------------
smallcluster (security group: @sc-smallcluster)
-----------------------------------------------
Launch time: 2014-06-16 09:57:54
Uptime: 0 days, 02:19:56
Zone: us-east-1b
Keypair: bioc-default
EBS volumes: N/A
Cluster nodes:
     master running i-46a76c6d ec2-54-91-23-93.compute-1.amazonaws.com
    node001 running i-47a76c6c ec2-54-224-6-153.compute-1.amazonaws.com
Total nodes: 2
```

So you can take the DNS name of the master (it starts with 'ec2-') and construct a URL by prepending `http://` and appending `:8787`, so something like:

```
http://ec2-54-224-6-153.compute-1.amazonaws.com:8787
```

Login is ubuntu/bioc.

## On the Master

You can play around at the OS command line. `qhost` will list all nodes.

You can start a simple job with:

```
qsub -b y -cwd hostname
```

Monitor job status with `qstat`. 

This will write output to files in the home directory.

Note that the home directory is shared across nodes:

```
touch thisfile
ssh node001 ls thisfile
```

## Using R

Before starting R, create a file ~/.BatchJobs with these contents:

```
cluster.functions = makeClusterFunctionsSGE('simple.tmpl')  
mail.start = "none"   
mail.done = "none"   
mail.error = "none"
db.driver = "SQLite"
db.options = list()
debug = FALSE
```

This is basically the default settings, the only thing changed is the value
of `cluster.functions`.

Also add a file in your home dir called simple.tmpl with these contents:

```
#!/bin/bash

# The name of the job, can be anything, simply used when displaying the list of 
running jobs
#$ -N <%= job.name %>
# Combining output/error messages into one file
#$ -j y
# Giving the name of the output log file
#$ -o <%= log.file %>
# One needs to tell the queue system to use the current directory as the working
 directory
# Or else the script may fail as it will execute in your top level home director
y /home/username
#$ -cwd
# use environment variables
#$ -V
# use correct queue 
$ -q <%= resources$queue %>
# use job arrays
#$ -t 1-<%= arrayjobs %>

# we merge R output with stdout from SGE, which gets then logged via -o option
R CMD BATCH --no-save --no-restore "<%= rscript %>" /dev/stdout
exit 0
```

This is from [https://github.com/tudo-r/BatchJobs/blob/master/examples/cfSGE/simple.tmpl](https://github.com/tudo-r/BatchJobs/blob/master/examples/cfSGE/simple.tmpl),
the only thing I changed was uncommenting the line after "use correct queue" because
BatchJobs complained about it. I don't really know what these lines do and if  they are important.

Now you can start R and when you load BatchJobs it will automatically use SGE as the back end.

You can now run the code you sent me:

```
library(BatchJobs)
 funs <- makeClusterFunctionsSGE("~/simple.tmpl")
library(BiocParallel)
 param <- BatchJobsParam(4, resources=list(ncpus=1),
                         cluster.functions=funs)
 register(param)
FUN <- function(i) system("hostname", intern=TRUE)
xx <- bplapply(1:100, FUN)
table(unlist(xx))
```

When you are done, be sure and 

```
starcluster terminate smallcluster
```

To stop paying for cluster usage.

## SSH Cluster

Note that you can also define a back end without a scheduler, just using ssh and the 
shared filesystem. See [this link](https://tudo-r.github.io/BatchJobs/man/makeClusterFunctionsSSH.html)
for more info.

I would like to replace the sections in our AMI page with instructions for doing this, as I think 
the StarCluster approach is more reliable. 

## MPI Cluster

I also think that StarCluster should be used for setting up a cluster to run MPI jobs, rather than what is documented in the AMI page (and we've seen doesn't work
very well).

You simply create a hostfile like this:

```
master slots=2
node001 slots=2
```

(Number of slots could vary depending on instance type).

Then start R like this:

```
mpirun -np 1 --hostfile hostfile.txt R --no-save --interactive
```

Using RStudio this way is a bit confusing as I recall and may require some more work. For now I'd encourage people to not use this option with RStudio. ;)

