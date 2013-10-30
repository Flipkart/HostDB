
HostDB
======

HostDB: a new tool to help manage data center inventory and write applications around it. 

HostDB is our attempt to solve the problem of finding hosts and their purposes in a large environment. HostDB acts as a Single source of truth about all Physical and Virtual servers and is used to define their purpose. It helps us group our servers through tags and all the software written by the operations team revolves around HostDB. HostDB acts as the centralized configuration store for all sorts of information.

Hosts
------

Any Host that exists is created inside HostDB upon birth and has information about itself in YAML. This info can be Hardware info, amount of CPU/RAM or Network FQDN, IP address, Rack, Switch, Physical location or Function, e.g what application software the host needs? The YAML can contain just about anything, it can be varied across hosts and can be ever evolving.

Tags
----

Hosts are grouped together with tags, similar to a host - a tag also has information about itself in YAML This information is applied to all hosts which are members of a tag. e.g a tag called VM can be applied to all virtual machines and can be used to define properties that are shared by all VMs. To be useful a tag must have member hosts.

Versioning
----------

HostDB provides versioning and the ability to roll back to a previous version for each and every host or tag.

API
---

The above concepts may look simple, but, can be used in extremely powerful ways with an API. and that’s exactly what HostDB provides. HostDB provides a REST api which can be used to create hosts, get members of a particular tag etc. We use this feature to automate just about everything at flipkart. Creating Virtual hosts, creating DNS records, automatic monitoring and escalations and building automated infrastructures. Services can do a periodic lookups to Hostdb and keep updating themselves of changes.



User Interfaces
---------------

HostDB provides a variety of user interfaces which can be used to interact with HostDB by applications and users.

* Web Application
* Rest API
* Command Line Interface
* HostDB::Client Perl Module
* Some example use of HostDB


HostDB: Key/Value Store with a difference
-----------------------------------------


HostDB is a key-value store, keys are grouped into namespaces based on type. ‘hosts’ is a special namespace which is central to all other namespaces. Keys inside ‘hosts’ are server names and their values contains mostly information and configuration details needed by server itself or applications it runs.

Applications can create unique keys(tags) which are application specific. You can add servers as ‘members’ of these keys which in turn helps you to consider your key(tag) as a group of hosts.

HostDB provides namespaces e.g you can create  keys(tags) that exist in a specific namespace and are access controlled, only member applications can read/write to keys of this namespace.  One can create access controls for each namespace or even for each key.

HostDB uses plain text files as its storage. The namespaces are represented as directories and keys are files inside the namespace directory. These files contain a key’s config in YAML.

The ‘members’ are also stored in files in a subdirectory in the namespace’s directory. The access permissions on the namespaces are also stored in a subdirectory.

GIT
----


The complete file structure of HostDB is in a git repository and git handles the versioning and transactions for HostDB. leveraging git means that we have a simple transactional store, which offers history as well as versioning. We can go to a previous version of a host or tag config at any point in time.

Web based Interface
-------------------

HostDB provides a Web based interface for uses to interact. 


Command Line tool
-----------------

HostDB provides a command line tool that is extremely helpful in writing those small bash one liners to get information out fast. Want to find out all machines with 24 GB of ram which are part of the search cluster. no problem!

<pre>

Add an object:
$ hostdb add hosts/hostdb.ops.ch.flipkart.com
Add host to tag:
$ hostdb add -m "adding new member" tags/nm-prod/members/new.nm.flipkart.com
Get host IP: 
$ hostdb get hosts/hostdb.ops.ch.flipkart.com/Network/IP
Get tag members: 
$ hostdb get tags/nm-prod/members

</pre>

HostDB::Client Perl Module
--------------------------

We use Perl extensively and have a Perl Module that can be used by applications to interact with HostDB.  This module provides an object oriented interface over HostDB REST API.

<pre>

use HostDB::Client;
my $hdb - HostDB::Client->new(\%options);
my $output - $hdb->get($id[, $revision, $raw]);
my $output - $hdb->revisions($id[, $limit]);

</pre>

HostDB has been central to almost all software written by the devops at flipkart and has allowed us to scale exponentially without a fuss. We hope you find it useful too. HostDB is now available on github, so go fork it,



Setting up Server
------------------

1. Copy Modules in src/site-perl to your module path (e.g., /usr/local/lib/site-perl)
2. Copy src/cgi-bin/hostdb_rest.fcgi to your CGI direcotry (e.g., /usr/lib/cgi-bin/)
3. Install config files in etc/samples to /etc and modify as needed
4. Put a cipher key in /var/lib/hostdb/cipher_key - Used for creating session token
5. Create a directory structure like this in /var/lib/hostdb/namespaces

<pre>

namespaces/
|-- .git/            <initialize your git repo here>
|-- hosts/           <’hosts’ namespace>
|   |-- server1      <server config - YAML>
|   |-- server2
|   |-- .perms/
|       |-- .global  <permissions(ACL) for ‘hosts’ namespace - YAML>
|       |-- server2  <any ACL overrides for server2 - YAML>
|-- tags/            <’tags’ namespace>
    |-- tag1         <a tag or hostgroup config - YAML>
    |-- tag2
    |-- .members/
    |   |-- tag1     <servers related to this tag - LIST>
    |   |-- tag2
    |-- .perms/
        |-- .global  <ACL for ‘tags’ namespace - YAML>
        |-- tag1     <any ACL override for tag1 - YAML>

ACL file format:
---
user1:
  data: RO
  members: RW
group1:
  members: RO

</pre>

6. All above files should be readable and writable for your apache user
7. Enable fcgid (a2enmod fcgid) if not already enabled
8. Restart apache
9. Test - https://hostdb.yourdomain.com/v1/

Setting up CLI tool
-------------------

1. Copy src/cli/hostdb to your bin directory
2. Copy src/site-perl/HostDB/Client.pm to your perl module dir
3. Copy etc/samples/hostdb/client_conf.yaml to /etc/hostdb/ and modify as needed
4. Test - hostdb get hosts

Setting up Web interface
------------------------

1. Copy src/www/hostdb to your document root
2. Modify src/www/hostdb/index.html to use correct cookie domain.
   Current code only supports 'hosts', 'tags' and 'spares' namespaces. You will have to modify it accordingly.
3. Configure hostdb apache config file as needed.
4. Test - https://hostdb.yourdomain.com

