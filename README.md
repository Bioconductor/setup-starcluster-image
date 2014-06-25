Creating a Bioconductor Virtual Machine
=======================================

This Vagrantfile and chef cookbook are designed for creating
the Bioconductor Amazon Machine Image (AMI), but could also
be used to provision a virtual machine (Virtualbox or VMware)
or a physical machine.

It's designed to work on Ubuntu but could be modified to work
on other Linux distributions.

It is typically used with a base StarCluster AMI to which
Chef has been added, but you could use it with any AMI
or Vagrant Box that has Chef installed.

You'll need Vagrant installed in order to use this.

To use, copy config.yml.example to config.yml and edit
config.yml to taste. If you are creating an Amazon AMI
you'll need the AWS plugin for Vagrant.
