vCloud Datacenter Operation Utilities (a.k.a. VCDKIT)
=====================================================

What is VCDKIT?
---------------

VCDKIT is a set of utility scripts which aims to help operations of
large scale [vCloud Datacenter](http://www.vmware.com/solutions/cloud-computing/public-cloud/vcloud-datacenter-services.html).
It is entirely written in Ruby for easier/flexible deployments.

With VCDKIT, vCloud administrator can do:

* Backup & restore vApp meta-data 
* Associate hardware errors(ESX host failure, Datastore failure) with affected vCD organization(tenant)
* Track peak Windows VM count for monthly license billing

Installation
---------------

### System Requirements

* OS: Tested with CentOS, Ubuntu, MacOSX
* Ruby: 1.8.7 (p174)

Configuration
---------------

### Connection Settings

1.  Click `Change Settings` link in `HOME` page
1.  Appropriately change connection settings for vCD and vCenter.
    For vCD, ensure to specify System Organization account. 
