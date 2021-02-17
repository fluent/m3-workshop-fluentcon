# M3 Workshop environment
 
## About

This repository contains all neccessary bits to run the M3 workshop stack locally on either Mac or Windows. Before getting started with the workshop, make sure you have met the following prerequisites below. During the workshop, we will be following the steps using a three-node M3DB cluster. If you don't have the capacity avaiable for this, we have also created a single-node version to follow along for most of the steps.  


### Prerequisites 

- Download [Docker Desktop](https://www.docker.com/products/docker-desktop) for Mac or Windows. [Docker Compose](https://docs.docker.com/compose) will be automatically installed. On Linux, make sure you have the latest version of [Compose](https://docs.docker.com/compose/install/). 

- Adjust "Resources" in Docker to have at least 8 GB of memory. (If using the single-node M3DB cluster, setting it to 3 GB will be sufficient.) 

## Stack overview

The stack consists of the latest versions of these components:

- A standalone M3DB node or a cluster of 3 nodes;
- [M3 Coordinator](https://m3db.io/docs/m3coordinator/) and [M3 Query](https://m3db.io/docs/m3query/) instances to interact w/ the [M3DB](https://m3db.io/docs/m3db/) nodes;
- Two [Prometheus](https://prometheus.io/docs/introduction/overview/) instances;
- A single [Grafana](https://grafana.com/) instance.

Both Prometheus instances are configured to scrape themselves and a slightly different sets of services. During the 
workshop, we'll demonstrate how querying the data on separate Prometheus instances will lead to slightly different results. 

The M3 Coordinator instance takes all read and write requests, and then distributes them to the cluster of M3DB nodes. It also implements Prometheus Remote Read and Write HTTP endpoints, which we'll use when modifying the Prometheus instances during the workshop.

The M3 Query instance is used to query all data from the M3DB cluster via Grafana.

At the start, Grafana will be configured with 3 different data sources - Prometheus01, Prometheus02, and M3Query: 

- [Prometheus instance 1](http://localhost:9090)
- [Prometheus instance 2](http://localhost:9091)
- [M3 Query endpoint](http://localhost:7221)

![Architecture diagram](./m3-workshop-schema.png)

**List of container instances**

| Container   | Endpoints 	| Notes		|
| ----------- | ----------- |-----------|
| prometheus01| [http://localhost:9090](http://localhost:9090)|The first Prometheus instance, scrapes itself and all M3 services, except M3 Query|
| prometheus02| [http://localhost:9091](http://localhost:9091)|The second Prometheus instance, scrapes all M3 services in the stack|
| grafana| [http://localhost:3030](http://localhost:3030)||
| m3db_seed	  | localhost:2379; localhost:909[0-2]| M3DB instance, running built-in etcd service (2379 TCP port). Runs in both single-node and cluster modes|
| m3db_data01 | localhost:909[0-2]  | This M3DB node runs in cluster mode only |
| m3db_data02 | localhost:909[0-2]  | This M3DB node runs in cluster mode only |
| m3coordinator01| 0.0.0.0:7201 | Exposes Prometheus Remote Read and Write API on TCP 7201 port |
| m3query01 	| 0.0.0.0:7221  | Exposes Prometheus Remote Read API on TCP 7221 port, used as a Grafana data source to query data in the M3DB cluster|
| provisioner | N/A | Prepares M3DB cluster on startup (creates M3DB namespace, placements)|

## Instructions for the workshop

### Step 1: Go to the M3 Workshop repo and clone the repo onto your local machine: 

Link to repo: https://github.com/m3dbx/m3-workshop

### Step 2: Start up the stack via Docker-Compose

For the three node M3DB cluster, run the following command:

```$:~ docker-compose up```

Once you see the following output (with code 0 at the end), the stack is configured and ready to be used: 

```
provisioner_1      | Waiting until shards are marked as available
provisioner_1      | Provisioning is done.
provisioner_1      | Prometheus available at http://localhost:9090
provisioner_1      | Prometheus replica is available at http://localhost:9091
provisioner_1      | Grafana available at http://localhost:3000
m3-workshop_provisioner_1 exited with code 0
```

Logs of the `provisioner` process can be seen either by following the output of the `docker-compose up` or by running the following command: ```docker-compose logs provisioner```

** If wanting to run the single M3DB node, run the following command instead:

```$:~ docker-compose -f single-node.yml up```

### Step 3: Open up Grafana 

Once the stack is up and running, login into the [Grafana](http://localhost:3030) using `admin:admin` credentials and then head to the [Explore](http://localhost:3000/explore) tab.

**Note:** Press "skip screen" in Grafana when prompting you to set a password. 

### Step 4: Explore the Prometheus data sources in Grafana

In the [Explore](http://localhost:3000/explore) tab of Grafana, you will see three datasources - Prometheus01, Prometheus02, and M3Query. Only the 2 Prometheus instances will be emitting metrics (scraping themselves), as remote read and write HTTP endpoints have not been enabled yet for your M3DB cluster. You can also see an example of a Grafana Dashboard for your metrics by X. 

Try switching between the two Prometheus datasources, and running the query command: 'up{}'. You will notice that each of the Prometheus instances are emitting slightly different sets of metrics, and that you would need to combine then in order to get a full picuture. In order to do this, we will be adding Remote Read and Write capabilities to the Prometheus instances in the next step. 

### Step 5 - Sending Prometheus metrics to the M3DB cluster

To start sending metrics scraped by the two Prometheus instances to the M3DB cluster, we need to enable remote write functionality:

- In your code editor of choice (we are using VSCode), go to the Prometheus folder under Config. There will be two `yml` config files there. At the bottom of each config file, there will be a Remote Read and Write seciont commented out (in green). Uncomment both `remote_read` and `remote_write` blocks in [./config/prometheus/prometheus01.yml](./config/prometheus/prometheus01.yml) and [./config/prometheus/prometheus02.yml](./config/prometheus/prometheus02.yml) config files. Once this is done, save your changes locally. 
- Then run `docker-compose restart prometheus01 prometheus02`;
- Once they're reloaded, head to the [Explore](http://localhost:3000/explore) tab and switch to the `M3 Query` data source to run PromQL queries (e.g. `up{}`. By doing so, you will now see that metrics across all of your instances are being emitted to the `M3 Query` data source. 


### Step 6 - Spin down one of the M3DB nodes (if running 3 node cluster) and query Prometheus metrics 

- When performing reads or writes, M3DB utilizes quorum logic in order to successfully complete requests. In order to demonstrate this, we will be spinning down of the M3DB nodes (**only if using 3 node cluster**) and querying against the remaining two nodes. 
- For this workshop, we will spin down `m3db_data01` by running the follwoing command:

```$:~ docker-compose stop m3db_data01```

- Once this is down, return to your `M3Query` data source in Grafana, and run a query command (e.g. `up{}`). You will see that the single node has been dropped, but that all remaining instances are still being successfully queried. 

### Step 7 - Spinning down the stack

Press `Ctrl+C` to interrupt the already running `docker-compose up` process, or run the following command:

```$:~ docker-compose down```

**Recommended step:** it leaves container disks intact. If you want to get rid of the data as well, run the following command:

```$:~ docker-compose down -v```

