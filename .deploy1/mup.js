module.exports = {
  servers: {
    one: {
      host: 'cocreate.csail.mit.edu',
      username: 'ubuntu',
      pem: "/afs/csail/u/e/edemaine/.ssh/private/id_rsa"
      // pem:
      // password:
      // or leave blank for authenticate from ssh-agent
    }
  },

  // Meteor server
  meteor: {
    name: 'cocreate',
    path: '/afs/csail/u/e/edemaine/Projects/cocreate',
    servers: {
      one: {}
    },
    docker: {
      image: 'zodern/meteor:latest',
      stopAppDuringPrepareBundle: false
    },
    buildOptions: {
      serverOnly: true,
      buildLocation: '/scratch/cocreate-build'
    },
    env: {
      ROOT_URL: 'https://cocreate.csail.mit.edu',
      //MAIL_URL: 'smtp://cocreate.csail.mit.edu:25?ignoreTLS=true',
      //MAIL_FROM: 'cocreate@cocreate.csail.mit.edu',
      MONGO_URL: 'mongodb://mongodb/meteor',
      //MONGO_OPLOG_URL: 'mongodb://mongodb/local',
      NODE_OPTIONS: '--trace-warnings --max-old-space-size=2048'
    },
    deployCheckWaitTime: 200,
  },

  // Mongo server
  mongo: {
    oplog: true,
    port: 27017,
    servers: {
      one: {},
    },
  },

  // Reverse proxy for SSL
  proxy: {
    domains: 'cocreate.csail.mit.edu',
    ssl: {
      letsEncryptEmail: 'edemaine@mit.edu',
      //crt: '../../cocreate_csail_mit_edu.ssl/cocreate_csail_mit_edu.pem',
      //key: '../../cocreate_csail_mit_edu.ssl/cocreate_csail_mit_edu.key',
      forceSSL: true,
    },
    clientUploadLimit: '0', // disable upload limit
    nginxServerConfig: '../.proxy.config',
  },

  // Run 'npm install' before deploying, to ensure packages are up-to-date
  hooks: {
    'pre.deploy': {
      localCommand: 'npm install'
    }
  },

  // Redis
  plugins: ['mup-redis'],
  redis: {
    servers: {
      one: {}
    },
    version: '6.0.8-alpine',
  },
};
