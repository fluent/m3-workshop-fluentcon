# M3 Workshop environment
 
## About

TBD

## Spinning up the stack

Run the following command:

```$:~ docker-compose up```

Once you see the following output, the stack is configured and ready to be used: 

```
provisioner_1      | Waiting until shards are marked as available
provisioner_1      | Provisioning is done.
provisioner_1      | Prometheus available at http://localhost:9090
provisioner_1      | Prometheus replica is available at http://localhost:9091
provisioner_1      | Grafana available at http://localhost:3000
m3-workshop_provisioner_1 exited with code 0
```

Logs of the provisioning process can be seen either by following the output of `docker-compose up` or by running the following command: ```docker-compose logs provisioner```


## Spinning down the stack

Press `Ctrl+C` to interrupt the already running `docker-compose up` process, or: 

```$:~ docker-compose down```

**NOTE:** the command above will leave container disks intact. If you want to get rid of the 
data as well, run the following command:


```$:~ docker-compose down -v```


## Requirements 

- Recent version of Docker Desktop;
- `docker-compose` utility;
- At least 8 GiB of RAM reserved for the Docker.
