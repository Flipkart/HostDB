<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta name="generator" content=
  "HTML Tidy for Linux/x86 (vers 25 March 2009), see www.w3.org" />

  <title>HostDB REST API</title>
  <meta content="text/html; charset=us-ascii" http-equiv="content-type" />
  <style type="text/css">
/*<![CDATA[*/
  ol{margin:0;padding:0}.c3{vertical-align:baseline;color:#000000;font-size:11pt;font-style:normal;font-family:"Arial";text-decoration:none;font-weight:normal}.c7{vertical-align:top;width:72pt;border-style:solid;border-color:#000000;border-width:1pt;padding:5pt 5pt 5pt 5pt}.c11{vertical-align:top;width:162pt;border-style:solid;border-color:#000000;border-width:1pt;padding:5pt 5pt 5pt 5pt}.c16{vertical-align:baseline;color:#000000;font-size:11pt;font-style:normal;font-family:"Arial";text-decoration:none}.c0{vertical-align:top;width:117pt;border-style:solid;border-color:#000000;border-width:1pt;padding:5pt 5pt 5pt 5pt}.c10{max-width:468pt;background-color:#ffffff;padding:72pt 72pt 72pt 72pt}.c13{margin-right:auto;border-collapse:collapse}.c2{padding-top:0pt;padding-bottom:0pt}.c1{line-height:1.0;direction:ltr}.c9{height:11pt;direction:ltr}.c4{text-align:left}.c15{height:11pt}.c6{height:0pt}.c5{text-align:center}.c12{direction:ltr}.c8{font-family:"Courier New"}.c14{font-weight:bold}.title{padding-top:0pt;line-height:1.15;text-align:left;color:#000000;font-size:21pt;font-family:"Trebuchet MS";padding-bottom:0pt}.subtitle{padding-top:0pt;line-height:1.15;text-align:left;color:#666666;font-style:italic;font-size:13pt;font-family:"Trebuchet MS";padding-bottom:10pt}li{color:#000000;font-size:11pt;font-family:"Arial"}p{color:#000000;font-size:11pt;margin:0;font-family:"Arial"}h1{padding-top:10pt;line-height:1.15;text-align:left;color:#000000;font-size:16pt;font-family:"Trebuchet MS";padding-bottom:0pt}h2{padding-top:10pt;line-height:1.15;text-align:left;color:#000000;font-size:13pt;font-family:"Trebuchet MS";font-weight:bold;padding-bottom:0pt}h3{padding-top:8pt;line-height:1.15;text-align:left;color:#666666;font-size:12pt;font-family:"Trebuchet MS";font-weight:bold;padding-bottom:0pt}h4{padding-top:8pt;line-height:1.15;text-align:left;color:#666666;font-size:11pt;text-decoration:underline;font-family:"Trebuchet MS";padding-bottom:0pt}h5{padding-top:8pt;line-height:1.15;text-align:left;color:#666666;font-size:11pt;font-family:"Trebuchet MS";padding-bottom:0pt}h6{padding-top:8pt;line-height:1.15;text-align:left;color:#666666;font-style:italic;font-size:11pt;font-family:"Trebuchet MS";padding-bottom:0pt}
  /*]]>*/
  </style>
</head>

<body class="c10">
  <p class="c12"><span>Assume a sample host config like this:</span></p>

  <p class="c12"><span class="c8">---</span></p>

  <p class="c12"><span class="c8">Network:</span></p>

  <p class="c12"><span class="c8">&nbsp; CNAME: somename.yourdomain.com</span></p>

  <p class="c12"><span class="c8">&nbsp; IP: 1.2.3.4</span></p>

  <p class="c9"></p><a href="#" name="fe6580d2d7acd54201e1823ee0fc6c3596357d2d" id=
  "fe6580d2d7acd54201e1823ee0fc6c3596357d2d"></a><a href="#" name="0"></a>

  <table cellpadding="0" cellspacing="0" class="c13">
    <tbody>
      <tr>
        <td class="c7">
          <p class="c2 c1 c5"><span class="c14">HTTP Method</span></p>
        </td>

        <td class="c11">
          <p class="c2 c1 c5"><span class="c14">End point</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c5"><span class="c14">Meaning</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c5"><span class="c14">Example</span></p>
        </td>
      </tr>

      <tr>
        <td class="c7">
          <p class="c2 c1"><span>GET</span></p>
        </td>

        <td class="c11">
          <p class="c2 c1"><span>/v1</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>Get a list(newline separated) of all
          namespaces</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4 c15"></p>
        </td>
      </tr>

      <tr>
        <td class="c7">
          <p class="c1 c2"><span>PUT/POST/DELETE</span></p>
        </td>

        <td class="c11">
          <p class="c2 c1"><span>/v1</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>Not Supported</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4 c15"></p>
        </td>
      </tr>

      <tr>
        <td class="c7">
          <p class="c2 c1"><span>GET</span></p>
        </td>

        <td class="c11">
          <p class="c2 c1"><span>/v1/namespace</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>Get a list(newline separated) of all keys in the
          namespace</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>/v1/hosts</span></p>
        </td>
      </tr>

      <tr>
        <td class="c7">
          <p class="c1"><span>PUT/POST/DELETE</span></p>
        </td>

        <td class="c11">
          <p class="c2 c1"><span>/v1/namespace</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>Not Supported</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4 c15"></p>
        </td>
      </tr>

      <tr>
        <td class="c7">
          <p class="c1"><span>GET</span></p>
        </td>

        <td class="c11">
          <p class="c1"><span>/v1/namespace/key</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>Get config for a particular key</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>/v1/tags/web_servers</span></p>
        </td>
      </tr>

      <tr>
        <td class="c7">
          <p class="c1"><span>PUT</span></p>
        </td>

        <td class="c11">
          <p class="c1"><span>/v1/namespace/key</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>Create a new key. Overwrite existing.</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>/v1/tags/DB_servers</span></p>

          <p class="c1"><span>PUTDATA: value=uri_escaped_yaml_data</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c7">
          <p class="c1"><span>POST</span></p>
        </td>

        <td class="c11">
          <p class="c1"><span>/v1/namespace/key</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>Rename a key</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>/v1/hosts/server1.yourdomain.com</span></p>

          <p class="c1"><span>POSTDATA:</span></p>

          <p class="c1"><span>newname=server2.yourdomain.com.com</span></p>
        </td>
      </tr>

      <tr>
        <td class="c7">
          <p class="c2 c1"><span>DELETE</span></p>
        </td>

        <td class="c11">
          <p class="c1"><span>/v1/namespace/key</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>Delete a key and all its meta information.</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>/v1/tags/testtag</span></p>
        </td>
      </tr>

      <tr>
        <td class="c7">
          <p class="c2 c1"><span>GET</span></p>
        </td>

        <td class="c11">
          <p class="c1"><span>/v1/namespace/key/members</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>Get members of a key as a list expanding all inherited
          members.</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>/v1/tags/web_servers/members</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c7">
          <p class="c2 c1 c4"><span>GET</span></p>
        </td>

        <td class="c11">
          <p class="c2 c1 c4"><span>/v1/namespace/key/members?raw=true</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>Get members in raw format. Does not expand inherited
          members.</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>/v1/tags/web_servers/members?raw=true</span></p>
        </td>
      </tr>

      <tr>
        <td class="c7">
          <p class="c1"><span>PUT</span></p>
        </td>

        <td class="c11">
          <p class="c1"><span>/v1/namespace/key/members</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>Set members of a key (raw format)</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>/v1/tags/web_servers/members</span></p>

          <p class="c1"><span>PUTDATA:</span></p>

          <p class="c1"><span>value=uri_escaped_list</span></p>
        </td>
      </tr>

      <tr>
        <td class="c7">
          <p class="c2 c1"><span>POST</span></p>
        </td>

        <td class="c11">
          <p class="c2 c1"><span>/v1/namespace/key/members</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>Not Supported</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4 c15"></p>
        </td>
      </tr>

      <tr>
        <td class="c7">
          <p class="c2 c1"><span>DELETE</span></p>
        </td>

        <td class="c11">
          <p class="c2 c1"><span>/v1/namespace/key/members</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>Delete all members</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>/v1/tags/web_servers/members</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c7">
          <p class="c2 c1 c4"><span>GET</span></p>
        </td>

        <td class="c11">
          <p class="c2 c1 c4"><span>/v1/namespace/key/members/hostname</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>Just returns hostname if it exists in
          members</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>/v1/tags/VM/testVM1</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c7">
          <p class="c2 c1 c4"><span>PUT</span></p>
        </td>

        <td class="c11">
          <p class="c1"><span>/v1/namespace/key/members/hostname</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>Add a member</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>/v1/tags/VM/testVM1</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c7">
          <p class="c2 c1 c4"><span>POST</span></p>
        </td>

        <td class="c11">
          <p class="c1"><span>/v1/namespace/key/members/hostname</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>Rename a member</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>/v1/tags/VM/testVM1</span></p>

          <p class="c2 c1 c4"><span>POSTDATA:</span></p>

          <p class="c2 c1 c4"><span>newname=testVM2</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c7">
          <p class="c2 c1 c4"><span>DELETE</span></p>
        </td>

        <td class="c11">
          <p class="c1"><span>/v1/namespace/key/members/hostname</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>Delete a member</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>/v1/tags/VM/testVM2</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c7">
          <p class="c2 c1 c4"><span>GET</span></p>
        </td>

        <td class="c11">
          <p class="c2 c1 c4"><span>/v1/namespace/key/config[/config/&hellip;]</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>Get a specific item inside key&rsquo;s
          config</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>/v1/hosts/server1.yourdomain.com/Network</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c7">
          <p class="c2 c1 c4"><span>PUT</span></p>
        </td>

        <td class="c11">
          <p class="c1"><span>/v1/namespace/key/config[/config/&hellip;]</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>Set a specific item inside key&rsquo;s config</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>/v1/hosts/server1.yourdomain.com/Network</span></p>

          <p class="c2 c1 c4"><span>PUTDATA: value=uri_escaped_yaml_data</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c7">
          <p class="c2 c1 c4"><span>POST</span></p>
        </td>

        <td class="c11">
          <p class="c1"><span>/v1/namespace/key/config[/config/&hellip;]</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>Rename a specific item inside key&rsquo;s config</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4">
          <span>/v1/hosts/server1.yourdomain.com/Network/CNAME</span></p>

          <p class="c2 c1 c4"><span>POSTDATA:</span></p>

          <p class="c2 c1 c4"><span>newname=cname</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c7">
          <p class="c2 c1 c4"><span>DELETE</span></p>
        </td>

        <td class="c11">
          <p class="c1"><span>/v1/namespace/key/config[/config/&hellip;]</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>Delete a specific item inside key&rsquo;s config</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4">
          <span>/v1/hosts/server1.yourdomain.com/Network/IP</span></p>
        </td>
      </tr>
    </tbody>
  </table>

  <p class="c9"></p>

  <p class="c12"><span>Extra functions:</span></p>

  <p class="c9"></p><a href="#" name="dfabf43565a1db463c875731360a91dd702af7d5" id=
  "dfabf43565a1db463c875731360a91dd702af7d5"></a><a href="#" name="1"></a>

  <table cellpadding="0" cellspacing="0" class="c13">
    <tbody>
      <tr>
        <td class="c0">
          <p class="c2 c1 c5"><span class="c14">HTTP Method</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c5"><span class="c14">End Point</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c5"><span class="c14">Meaning</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c5"><span class="c14">Example</span></p>
        </td>
      </tr>

      <tr>
        <td class="c0">
          <p class="c2 c1"><span>GET</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>any_uri?search=regex</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>output only lines matching the regex</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>/v1/hosts?search=stage</span></p>
        </td>
      </tr>

      <tr>
        <td class="c0">
          <p class="c2 c1"><span>GET</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>/v1/hosts/key?meta=parents&amp;from=namespace</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>Parents of a host in a namespace. Like
          &lsquo;tagofhost&rsquo;.</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1">
          <span>/v1/hosts/server1.yourdomain.com?meta=parents&amp;from=tags</span></p>
        </td>
      </tr>

      <tr>
        <td class="c0">
          <p class="c1"><span>GET</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>/v1/hosts/key?meta=derived&amp;from=namespace</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>Derived Config of a host in a namespace. (Combined config
          of all parents)</span></p>
        </td>

        <td class="c0">
          <p class="c1">
          <span>/v1/hosts/server1.yourdomain.com?meta=derived&amp;from=tags</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c0">
          <p class="c2 c1 c4"><span>GET</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>any_uri?meta=revisions[&amp;limit=n]</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>Last n revision ids of an object. Default
          n=50.</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4">
          <span>/v1/hosts/server1.yourdomain.com?meta=revisions&amp;limit=10</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c0">
          <p class="c2 c1 c4"><span>GET</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>any_uri?revision=&lt;revision_id&gt;</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>Gives the contents of the object for the specified
          revision</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4">
          <span>/v1/hosts/server1.yourdomain.com?revision=u2eoajwoiqjdoqw</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c0">
          <p class="c2 c1 c4"><span>GET</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>any_url?foreach=&lt;resource_id&gt;</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>Iterates over all keys generated from resource
          id</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>get IPs of all web servers:
          v1/hosts/*/Network/IP?foreach=tags/web_servers/members</span></p>
        </td>
      </tr>
    </tbody>
  </table>

  <p class="c9"></p>

  <p class="c12"><span>Auth functions:</span></p>

  <p class="c9"></p><a href="#" name="e2f61581f040e3ce96178c539dd60d4cea551c93" id=
  "e2f61581f040e3ce96178c539dd60d4cea551c93"></a><a href="#" name="2"></a>

  <table cellpadding="0" cellspacing="0" class="c13">
    <tbody>
      <tr class="c6">
        <td class="c0">
          <p class="c1 c5"><span class="c14">HTTP Method</span></p>
        </td>

        <td class="c0">
          <p class="c1 c5"><span class="c14">End Point</span></p>
        </td>

        <td class="c0">
          <p class="c1 c5"><span class="c14">Meaning</span></p>
        </td>

        <td class="c0">
          <p class="c1 c5"><span class="c14">Example</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c0">
          <p class="c2 c1"><span>POST</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>/v1/auth/session</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>create a new session token</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>/v1/auth/session</span></p>

          <p class="c2 c1"><span>POSTDATA:</span></p>

          <p class="c2 c1"><span>username=user&amp;password=secret</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c0">
          <p class="c2 c1"><span>GET</span></p>
        </td>

        <td class="c0">
          <p class="c1"><span>/v1/auth/session/&lt;session_id&gt;</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>Validate a session token</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1"><span>/v1/auth/session/aldha3i4rf738w7o5y5sey85iu</span></p>
        </td>
      </tr>

      <tr class="c6">
        <td class="c0">
          <p class="c2 c1 c4"><span>GET</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4">
          <span>/v1/auth/can_modify?user=&lt;username&gt;&amp;id=&lt;resource_id&gt;</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4"><span>check if user has permission to modify
          resource</span></p>
        </td>

        <td class="c0">
          <p class="c2 c1 c4 c15"></p>
        </td>
      </tr>
    </tbody>
  </table>

  <p class="c9"></p>
</body>
</html>

