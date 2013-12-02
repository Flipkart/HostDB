HostDB API Specification
========================

Assume a sample host config like this:

<pre>

---
Network:
  CNAME: somename.yourdomain.com
  IP: 1.2.3.4

</pre>

<table>
<tr>
<th>HTTP Method</th>
<th>End point</th>
<th>Meaning</th>
<th>Example</th>
</tr>
<tr>
<td>GET</td>
<td>/v1</td>
<td>Get a list(newline separated) of all namespaces</td>
<td></td>
</tr>
<tr>
<td>PUT/POST/DELETE</td>
<td>/v1</td>
<td>Not Supported</td>
<td></td>
</tr>
<tr>
<td>GET</td>
<td>/v1/namespace</td>
<td>Get a list(newline separated) of all keys in the namespace</td>
<td>/v1/hosts</td>
</tr>
<tr>
<td>PUT/POST/DELETE</td>
<td>/v1/namespace</td>
<td>Not Supported</td>
<td></td>
</tr>
<tr>
<td>GET</td>
<td>/v1/namespace/key</td>
<td>Get config for a particular key</td>
<td>/v1/tags/web_servers</td>
</tr>
<tr>
<td>PUT</td>
<td>/v1/namespace/key</td>
<td>Create a new key. Overwrite existing.</td>
<td>/v1/tags/DB_servers PUTDATA: value=uri_escaped_yaml_data</td>
</tr>
<tr>
<td>POST</td>
<td>/v1/namespace/key</td>
<td>Rename a key</td>
<td>/v1/hosts/server1.yourdomain.com POSTDATA: newname=server2.yourdomain.com.com</td>
</tr>
<tr>
<td>DELETE</td>
<td>/v1/namespace/key</td>
<td>Delete a key and all its meta information.</td>
<td>/v1/tags/testtag</td>
</tr>
<tr>
<td>GET</td>
<td>/v1/namespace/key/members</td>
<td>Get members of a key as a list expanding all inherited members.</td>
<td>/v1/tags/web_servers/members</td>
</tr>
<tr>
<td>GET</td>
<td>/v1/namespace/key/members?raw=true</td>
<td>Get members in raw format. Does not expand inherited members.</td>
<td>/v1/tags/web_servers/members?raw=true</td>
</tr>
<tr>
<td>PUT</td>
<td>/v1/namespace/key/members</td>
<td>Set members of a key (raw format)</td>
<td>/v1/tags/web_servers/members PUTDATA: value=uri_escaped_list</td>
</tr>
<tr>
<td>POST</td>
<td>/v1/namespace/key/members</td>
<td>Not Supported</td>
<td></td>
</tr>
<tr>
<td>DELETE</td>
<td>/v1/namespace/key/members</td>
<td>Delete all members</td>
<td>/v1/tags/web_servers/members</td>
</tr>
<tr>
<td>GET</td>
<td>/v1/namespace/key/members/hostname</td>
<td>Just returns hostname if it exists in members</td>
<td>/v1/tags/VM/testVM1</td>
</tr>
<tr>
<td>PUT</td>
<td>/v1/namespace/key/members/hostname</td>
<td>Add a member</td>
<td>/v1/tags/VM/testVM1</td>
</tr>
<tr>
<td>POST</td>
<td>/v1/namespace/key/members/hostname</td>
<td>Rename a member</td>
<td>/v1/tags/VM/testVM1 POSTDATA: newname=testVM2</td>
</tr>
<tr>
<td>DELETE</td>
<td>/v1/namespace/key/members/hostname</td>
<td>Delete a member</td>
<td>/v1/tags/VM/testVM2</td>
</tr>
<tr>
<td>GET</td>
<td>/v1/namespace/key/config[/config/…]</td>
<td>Get a specific item inside key’s config</td>
<td>/v1/hosts/server1.yourdomain.com/Network</td>
</tr>
<tr>
<td>PUT</td>
<td>/v1/namespace/key/config[/config/…]</td>
<td>Set a specific item inside key’s config</td>
<td>/v1/hosts/server1.yourdomain.com/Network PUTDATA: value=uri_escaped_yaml_data</td>
</tr>
<tr>
<td>POST</td>
<td>/v1/namespace/key/config[/config/…]</td>
<td>Rename a specific item inside key’s config</td>
<td>/v1/hosts/server1.yourdomain.com/Network/CNAME POSTDATA: newname=cname</td>
</tr>
<tr>
<td>DELETE</td>
<td>/v1/namespace/key/config[/config/…]</td>
<td>Delete a specific item inside key’s config</td>
<td>/v1/hosts/server1.yourdomain.com/Network/IP</td>
</tr>
</table>

Extra functions:
----------------

<table>
<tr>
<th>HTTP Method</th>
<th>End Point</th>
<th>Meaning</th>
<th>Example</th>
</tr>
<tr>
<td>GET</td>
<td>any_uri?search=regex</td>
<td>output only lines matching the regex</td>
<td>/v1/hosts?search=stage</td>
</tr>
<tr>
<td>GET</td>
<td>/v1/hosts/key?meta=parents&from=namespace</td>
<td>Parents of a host in a namespace. Like ‘tagofhost’.</td>
<td>/v1/hosts/server1.yourdomain.com?meta=parents&from=tags</td>
</tr>
<tr>
<td>GET</td>
<td>/v1/hosts/key?meta=derived&from=namespace</td>
<td>Derived Config of a host in a namespace. (Combined config of all parents)</td>
<td>/v1/hosts/server1.yourdomain.com?meta=derived&from=tags</td>
</tr>
<tr>
<td>GET</td>
<td>any_uri?meta=revisions[&limit=n]</td>
<td>Last n revision ids of an object. Default n=50.</td>
<td>/v1/hosts/server1.yourdomain.com?meta=revisions&limit=10</td>
</tr>
<tr>
<td>GET</td>
<td>any_uri?revision=<revision_id></td>
<td>Gives the contents of the object for the specified revision</td>
<td>/v1/hosts/server1.yourdomain.com?revision=u2eoajwoiqjdoqw</td>
</tr>
<tr>
<td>GET</td>
<td>any_url?foreach=<resource_id></td>
<td>Iterates over all keys generated from resource id</td>
<td>get IPs of all web servers: v1/hosts/*/Network/IP?foreach=tags/web_servers/members</td>
</tr>
</table>

Auth functions:
---------------

<table>
<tr>
<th>HTTP Method</th>
<th>End Point</th>
<th>Meaning</th>
<th>Example</th>
</tr>
<tr>
<td>POST</td>
<td>/v1/auth/session</td>
<td>create a new session token</td>
<td>/v1/auth/session POSTDATA: username=user&password=secret</td>
</tr>
<tr>
<td>GET</td>
<td>/v1/auth/session/<session_id></td>
<td>Validate a session token</td>
<td>/v1/auth/session/aldha3i4rf738w7o5y5sey85iu</td>
</tr>
<tr>
<td>GET</td>
<td>/v1/auth/can_modify?user=<username>&id=<resource_id></td>
<td>check if user has permission to modify resource</td>
<td></td>
</tr>
</table>


