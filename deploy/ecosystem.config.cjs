module.exports = {
  apps: [
    {
      name: "ris-backend",
      cwd: ".",
      script: "server.js",
      interpreter: "node",
      instances: 1,
      exec_mode: "fork",
      watch: false,
      restart_delay: 5000,
      kill_timeout: 10000,
      env: {
        NODE_ENV: process.env.NODE_ENV || "development",
        PORT: process.env.APP_PORT || process.env.PORT || 3000,
      },
      env_production: {
        NODE_ENV: "production",
      },
    },
  ],
};

