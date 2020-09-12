# Installing a Cocreate Server

These instructions on based on the more complicated
[installation instructions for Coauthor](https://github.com/edemaine/coauthor/blob/master/INSTALL.md).

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
Installation instructions:

1. Install Meteor and download Cocreate as above.
2. Install [`mup`](http://meteor-up.com/) and
   [`mup-redis`](https://github.com/zodern/mup-redis)
   via `npm install -g mup mup-redis`
   (after installing [Node](https://nodejs.org/en/) and thus NPM).
3. Copy `settings.json` to `.deploy/settings.json` and edit if desired
   (see configuration choices mentioned below).
4. Edit `.deploy/mup.js` to point to your SSH key (for accessing the server).
5. `cd .deploy`
6. `mup setup` to install all necessary software on the server.
7. `mup deploy` each time you want to deploy code to server
   (initially and after each `git pull`).

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

## bcrypt on Windows

To install `bcrypt` on Windows (to avoid warnings about it missing), install
[windows-build-tools](https://www.npmjs.com/package/windows-build-tools)
via `npm install --global --production windows-build-tools`, and
then run `meteor npm install bcrypt`.
