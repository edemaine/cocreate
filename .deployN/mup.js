module.exports = {
  servers: {
    proxy: {
      host: 'cocreate-proxy.csail.mit.edu',
      username: 'ubuntu',
      pem: "/afs/csail/u/e/edemaine/.ssh/private/id_rsa"
    },
    worker1: {
      host: 'cocreate-worker1.csail.mit.edu',
      username: 'ubuntu',
      pem: "/afs/csail/u/e/edemaine/.ssh/private/id_rsa"
    },
    worker2: {
      host: 'cocreate-worker2.csail.mit.edu',
      username: 'ubuntu',
      pem: "/afs/csail/u/e/edemaine/.ssh/private/id_rsa"
    },
    worker3: {
      host: 'cocreate-worker3.csail.mit.edu',
      username: 'ubuntu',
      pem: "/afs/csail/u/e/edemaine/.ssh/private/id_rsa"
    },
    worker4: {
      host: 'cocreate-worker4.csail.mit.edu',
      username: 'ubuntu',
      pem: "/afs/csail/u/e/edemaine/.ssh/private/id_rsa"
    },
  },

  // Meteor server
  meteor: {
    name: 'cocreate',
    path: '/afs/csail/u/e/edemaine/Projects/cocreate',
    servers: {
      worker1: {env: {COCREATE_WORKER: '1'}},
      worker2: {env: {COCREATE_WORKER: '2', COCREATE_SKIP_UPGRADE_DB: '1'}},
      worker3: {env: {COCREATE_WORKER: '3', COCREATE_SKIP_UPGRADE_DB: '1'}},
      worker4: {env: {COCREATE_WORKER: '4', COCREATE_SKIP_UPGRADE_DB: '1'}},
    },
    docker: {
      image: 'abernix/meteord:node-12-base',
      stopAppDuringPrepareBundle: true,
    },
    buildOptions: {
      serverOnly: true,
      buildLocation: '/scratch/cocreate-build'
    },
    env: {
      ROOT_URL: 'https://cocreate.csail.mit.edu',
      //MAIL_URL: 'smtp://cocreate.csail.mit.edu:25?ignoreTLS=true',
      //MAIL_FROM: 'cocreate@cocreate.csail.mit.edu',
      MONGO_URL: 'mongodb://cocreate-mongo.csail.mit.edu/cocreate',
      //MONGO_OPLOG_URL: 'mongodb://mongodb/local',
      NODE_OPTIONS: '--trace-warnings --max-old-space-size=1024'
    },
    deployCheckWaitTime: 200,
  },

  // Reverse proxy for SSL
  proxy: {
    servers: {
      proxy: {},
    },
    domains: 'cocreate.csail.mit.edu,cocreate-proxy.csail.mit.edu',
    ssl: {
      letsEncryptEmail: 'edemaine@mit.edu',
      //crt: '../../cocreate_csail_mit_edu.ssl/cocreate_csail_mit_edu.pem',
      //key: '../../cocreate_csail_mit_edu.ssl/cocreate_csail_mit_edu.key',
      forceSSL: true,
    },
    clientUploadLimit: '0', // disable upload limit
    nginxServerConfig: '../.proxy.config',
    loadBalancing: true,
  },

  // Run 'npm install' before deploying, to ensure packages are up-to-date
  hooks: {
    'pre.deploy': {
      localCommand: 'npm install'
    }
  },
};
