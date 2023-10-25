# Sample Application 🏜️

This is a sample RODA application that test the current implementation of the `rollout-redis` gem.

If you want to run it, you just need to perform:

```shell
bundle install && rackup
```

It will start a server in [http://localhost:9292](http://localhost:9292)

```shell
Puma starting in single mode...
* Puma version: 5.6.7 (ruby 3.2.2-p53) ("Birdie's Version")
*  Min threads: 0
*  Max threads: 5
*  Environment: development
*          PID: 43818
* Listening on http://127.0.0.1:9292
* Listening on http://[::1]:9292
Use Ctrl-C to stop
```

If you want to test the notifications, please edit the `config.ru` file and update the `SLACK_WEBHOOK_URL` and `SMTP_HOST` variables when defining the available channels.