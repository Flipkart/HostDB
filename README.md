
HostDB
======

HostDB: a new tool to help manage data center inventory and write applications around it. 

HostDB is our attempt to solve the problem of finding hosts and their purposes in a large environment. HostDB acts as a Single source of truth about all Physical and Virtual servers and is used to define their purpose. It helps us group our servers through tags and all the software written by the operations team revolves around HostDB. HostDB acts as the centralized configuration store for all sorts of information.

Hosts
======

Any Host that exists is created inside HostDB upon birth and has information about itself in YAML. This info can be Hardware info, amount of CPU/RAM or Network FQDN, IP address, Rack, Switch, Physical location or Function, e.g what application software the host needs? The YAML can contain just about anything, it can be varied across hosts and can be ever evolving.

Tags
====

Hosts are grouped together with tags, similar to a host - a tag also has information about itself in YAML This information is applied to all hosts which are members of a tag. e.g a tag called VM can be applied to all virtual machines and can be used to define properties that are shared by all VMs. To be useful a tag must have member hosts.

Versioning
==========

HostDB provides versioning and the ability to roll back to a previous version for each and every host or tag.

API
===

The above concepts may look simple, but, can be used in extremely powerful ways with an API. and that’s exactly what HostDB provides. HostDB provides a REST api which can be used to create hosts, get members of a particular tag etc. We use this feature to automate just about everything at flipkart. Creating Virtual hosts, creating DNS records, automatic monitoring and escalations and building automated infrastructures. Services can do a periodic lookups to Hostdb and keep updating themselves of changes.



User Interfaces
===============

HostDB provides a variety of user interfaces which can be used to interact with HostDB by applications and users.

* Web Application
* Rest API
* Command Line Interface
* HostDB::Client Perl Module
* Some example use of HostDB


HostDB: The Details
===================

Sometime in 2011, While flipkart was growing at an exponential scale and the entire operations team consisted of four people. We constantly struggled to allocate hardware and to make it production ready. Cloning machines using FAI, adding monitoring, adding dns entries etc were all routine pre-defined tasks which we felt could be automated very easily. We were tracking all of this with a shared google spreadsheet which was never kept up to date. Many a times existing machines were allocated twice, or more disastrously,  re-cloned by mistake. Surely, there was a better way.

At the same time we were also thinking about a virtualization strategy, the open source options that were available at the time did not make any waves for us. So we decided to write our own, something we call Kloud. It was in these discussions that we thought about the life cycle of a machine and how instead of a centralised datastore keeping machine info, we really needed an application which could talk to other applications about the purpose of a host and it’s properties.

We looked at all the available options and were disappointed. We decided to write something which was not just a source of truth about a host, but interacted with the production environment and lived with it. Because we wrote it to automate infrastructure problems, host state and host properties comes naturally to HostDB. We kept availability, scalability and reliability as the most important features of HostDB. As It turns out HostDB scales wonderfully for thousands of clients.

Since we were such a small team, we were constantly involved in firefights and didn’t have any time to manage new services. We didn’t want to write something that depended on external services like zookeeper or mysql etc and decided to keep all the data in text files, “if it didn’t scale, we’ll change it later” was the policy.  We also wanted to future proof it and so stayed away from any complex file formats. The first prototype was written in Python by Abhishek. Both Krishnan and I refuse to read Python and Krishnan rewrote the whole thing in Perl one night. A year later another rewrite done by Jain Jonny incorporated the concept of multiple namespaces and made the code much more modular. We’ve been running this version in production for over a year now.



HostDB: Key/Value Store with a difference
=========================================



HostDB is a key-value store, keys are grouped into namespaces based on type. ‘hosts’ is a special namespace which is central to all other namespaces. Keys inside ‘hosts’ are server names and their values contains mostly information and configuration details needed by server itself or applications it runs.

Applications can create unique keys(tags) which are application specific. You can add servers as ‘members’ of these keys which in turn helps you to consider your key(tag) as a group of hosts.

HostDB provides namespaces e.g you can create  keys(tags) that exist in a specific namespace and are access controlled, only member applications can read/write to keys of this namespace.  One can create access controls for each namespace or even for each key.

HostDB uses plain text files as its storage. The namespaces are represented as directories and keys are files inside the namespace directory. These files contain a key’s config in YAML.

The ‘members’ are also stored in files in a subdirectory in the namespace’s directory. The access permissions on the namespaces are also stored in a subdirectory.

GIT
====


The complete file structure of HostDB is in a git repository and git handles the versioning and transactions for HostDB. leveraging git means that we have a simple transactional store, which offers history as well as versioning. We can go to a previous version of a host or tag config at any point in time.

Web based Interface
===================


HostDB provides a Web based interface for uses to interact. 


Command Line tool
=================

HostDB provides a command line tool that is extremely helpful in writing those small bash one liners to get information out fast. Want to find out all machines with 24 GB of ram which are part of the search cluster. no problem!

Add an object:
$ hostdb add hosts/hostdb.ops.ch.flipkart.com
Add host to tag:
$ hostdb add -m "adding new member" tags/nm-prod/members/new.nm.flipkart.com
Get host IP: 
$ hostdb get hosts/hostdb.ops.ch.flipkart.com/Network/IP
Get tag members: 
$ hostdb get tags/nm-prod/members



HostDB::Client PerI Module
==========================

We use Perl extensively and have a Perl Module that can be used by applications to interact with HostDB.  This module provides an object oriented interface over HostDB REST API.

use HostDB::Client;
my $hdb = HostDB::Client->new(\%options);
my $output = $hdb->get($id[, $revision, $raw]);
my $output = $hdb->revisions($id[, $limit]);


HostDB has been central to almost all software written by the devops at flipkart and has allowed us to scale exponentially without a fuss. We hope you find it useful too. HostDB is now available on github, so go fork it,











