# Installing a Cocreate Server

These instructions on based on the more complicated
[installation instructions for Coauthor](https://github.com/edemaine/coauthor/blob/main/INSTALL.md).

## Test Server

Here is how to get a **local test server** running:

1. **[Install Meteor](https://www.meteor.com/install):**
   `curl https://install.meteor.com/ | sh` on UNIX,
   `choco install meteor` on Windows (in administrator command prompt
   after [installing Chocolatey](https://chocolatey.org/install))
2. **Download Cocreate:** `git clone https://github.com/edemaine/cocreate.git`
3. **Run meteor:**
   * `cd cocreate`
   * `meteor npm install`
   * `meteor`
   

Even a test server will be accessible from the rest of the Internet,
on port 3000.

## Public Server

To deploy to a **public server**, we recommend deploying from a development
machine via [meteor-up](http://meteor-up.com/).
We provide two example deployment configurations:

### Single Machine

We've found that one machine running everything (Meteor, MongoDB, Redis, proxy)
to be reasonable for up to ~50 simultaneous users,
given ~2-4GB of RAM and 1-2 cores.
This configuration can be achieved fully automatically via `mup` as follows:

1. Install Meteor and download Cocreate as above.
2. Install [`mup`](http://meteor-up.com/) and
   [`mup-redis`](https://github.com/zodern/mup-redis)
   via `npm install -g mup mup-redis`
   (after installing [Node](https://nodejs.org/en/) and thus NPM).
3. Copy `settings.json` to `.deploy1/settings.json` and edit.
   In particular, you should change the `cors-anywhere` setting to point to
   your own [CORS Anywhere server](https://github.com/Rob--W/cors-anywhere/),
   or remove that setting altogether (to disable image loading via proxy).
   For further configuration choices for `settings.json`, see
   [APM](#application-performance-management-apm) and [CDN](#cdn) below.
4. Edit `.deploy1/mup.js` to point to your hostname/IP and SSH key
   (for accessing the server), and maybe adjust RAM available to Meteor.
5. `cd .deploy1`
6. `mup setup` to install all necessary software on the server.
7. `mup deploy` each time you want to deploy code to server
   (initially and after each `git pull`).

### Multiple Machines (Scaling)

To scale beyond ~50 simultaneous users, we offer a different deployment
configuration in the [`.deployN`](.deployN) directory.  It runs the
following arrangement of servers:

Number | Tasks | Recommended configuration
-------|-------|--------------------------
several (currently 4) | Meteor servers | 2GB RAM (1GB causes occasional crashes), 1 core
one | MongoDB server | 4GB RAM, 4 cores
one | Redis and proxy | 1GB RAM, 1 core, open to ports 80 and 443

The nginx reverse proxy is the public facing web server (and should be the
only server with publicly open ports), and automatically distributes
requests to the Meteor servers (by IP hashing), automatically detecting
crashed/upgrading servers and using the other servers to compensate.
You should firewall the other servers (and the Redis server on
the proxy machine) to protect them from outside access.

`mup` handles deployment of the Meteor servers and nginx reverse proxy.
You need to manually setup the MongoDB and Redis servers.

As in the provided [`mup.js`](.deployN/mup.js), all Meteor servers except one
should have the `COCREATE_SKIP_UPGRADE_DB` environment variable set, to avoid
multiple servers from upgrading the Cocreate database format from older
versions.

## Application Performance Management (APM)

To monitor server performance, you can use one of the following:

* [Monti APM](https://montiapm.com/)
  (no setup required, free for 8-hour retention); or
* deploy your own
  [open-source Kadira server](https://github.com/kadira-open/kadira-server).
  To get this running (on a different machine), I recommend
  [kadira-compose](https://github.com/edemaine/kadira-compose).

After creating an application on one of the servers above,
edit your `.deploy/settings.json` to include the following
(omit `endpoint` if you're using Monti):

```json
{
  "kadira": {
    "appId": "xxxxxxxxxxxxxxxxx",
    "appSecret": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "endpoint": "https://your-kadira-server:22022"
  }
}
```

## MongoDB

All of Cocreate's data is stored in the Mongo database
(which is part of Meteor).
You probably want to do regular (e.g. daily) dump backups.
<!--
There's a script in `.backup` that I use to dump the database,
copy to the development machine, and upload to Dropbox or other cloud storage
via [rclone](https://rclone.org/).
-->

`mup`'s MongoDB stores data in `/var/lib/mongodb`.  MongoDB prefers an XFS
filesystem, so you might want to
[create an XFS filesystem](http://ask.xmodulo.com/create-mount-xfs-file-system-linux.html)
and mount or link it there.
(For example, I have mounted an XFS volume at `/data` and linked via
`ln -s /data/mongodb /var/lib/mongodb`).

`mup` also, by default, makes the MongoDB accessible to any user on the
deployed machine.  This is a security hole: make sure that there aren't any
user accounts on the deployed machine.
But it is also useful for manual database inspection and/or manipulation.
[Install MongoDB client
tools](https://docs.mongodb.com/manual/administration/install-community/),
run `mongo cocreate` (or `mongo` then `use cocreate`) and you can directly
query or update the collections.  (Start with `show collections`, then
e.g. `db.messages.find()`.)
On a test server, you can run `meteor mongo` to get the same interface.

## CDN

Cocreate uses
[tex2svg-webworker](https://github.com/edemaine/tex2svg-webworker/)
to render LaTeX math.
For sake of performance, we recommend serving this rather large WebWorker
script via CDN, and the [provided `settings.json`](settings.json)
does so via [JSDelivr](https://www.jsdelivr.com/).
You can configure your `.deploy/settings.json` to use a different CDN as follows:

```json
{
  "public": {
    "tex2svg": "https://your.cdn/tex2svg.js"
  }
}
```

Without this setting, e.g. when developing via `meteor`,
the WebWorker script will be served from the Cocreate server.

## CORS Anywhere Proxy

To enable flexible [embedding images from the web](doc/README.md#-image-tool),
including those restricted by CORS, we recommend installing a
[CORS Anywhere](https://github.com/Rob--W/cors-anywhere) proxy server and
configuring Cocreate to use it by setting the `cors-anywhere` public setting
in `.deploy/settings.json`.  For example, here is how to use the CORS Anywhere
public test server, which is rate limited and for development only:

```json
{
  "public": {
    "cors-anywhere": "https://cors-anywhere.herokuapp.com/"
  }
}
```

CORS Anywhere is a framework for making proxy servers.  A good specific server
is [Corsproxy](https://github.com/caltechlibrary/corsproxy) which has
[easy-to-follow installation instructions](https://github.com/caltechlibrary/corsproxy/blob/main/admin/README.md)
(for ports &ge; 1024, e.g., 8080), along with the accompanying
[certbot letsencrypt installation instructions](https://certbot.eff.org/lets-encrypt/debiantesting-other)
for SSL certificates.
While it may be tempting to set `REQUIRED_HEADER="Origin"`,
[Firefox won't send Origin headers for images](https://wiki.mozilla.org/Security/Origin#When_Origin_is_served_-9.72and_when_it_is_.22null.22.29)
so it's best to leave it empty.

If you omit the `cors-anywhere` setting, Cocreate will never attempt to proxy
embedded images, so more images will fail to embed.

## bcrypt on Windows

To install `bcrypt` on Windows (to avoid warnings about it missing), install
[windows-build-tools](https://www.npmjs.com/package/windows-build-tools)
via `npm install --global --production windows-build-tools`, and
then run `meteor npm install bcrypt`.
