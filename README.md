[![Build Status](https://travis-ci.org/microservices-demo/microservices-demo.svg?branch=master)](https://travis-ci.org/microservices-demo/microservices-demo)

# DEPRECATED: Sock Shop : A Microservice Demo Application

The application is the user-facing part of an online shop that sells socks. It is intended to aid the demonstration and testing of microservice and cloud native technologies.

It is built using [Spring Boot](http://projects.spring.io/spring-boot/), [Go kit](http://gokit.io) and [Node.js](https://nodejs.org/) and is packaged in Docker containers.

You can read more about the [application design](./internal-docs/design.md).

## Deployment Platforms

The [deploy folder](./deploy/) contains scripts and instructions to provision the application onto your favourite platform.

Please let us know if there is a platform that you would like to see supported.

## Bugs, Feature Requests and Contributing

We'd love to see community contributions. We like to keep it simple and use Github issues to track bugs and feature requests and pull requests to manage contributions. See the [contribution information](.github/CONTRIBUTING.md) for more information.

## Screenshot

![Sock Shop frontend](https://github.com/microservices-demo/microservices-demo.github.io/raw/master/assets/sockshop-frontend.png)

## Visualizing the application

Use [Weave Scope](http://weave.works/products/weave-scope/) or [Weave Cloud](http://cloud.weave.works/) to visualize the application once it's running in the selected [target platform](./deploy/).

![Sock Shop in Weave Scope](https://github.com/microservices-demo/microservices-demo.github.io/raw/master/assets/sockshop-scope.png)

## Deploying in GCP with terraform:

### Requisites:

To follow the step by step yo need:

* gcloud (logged in and asociated to project with an active billing account)
* kubectl (to handle K8s resources)

### Procedure:

To deploy the cluster into a GKE in GCP, you need the previously defined tools installed and configured in your own computer.

After having all set, you may need to give `deploy.sh` execution permissions

```bash
$ chmod +x deploy.sh
```

And then run:

```bash
$ ./deploy.sh
```

This process may take arround 20 minutes. And will:

1. Create the corresponding infraestructure (networks and GKE cluster ready and running)
2. Apply the K8s demo manifests which will deploy a pod of each microservice + other configuration resources including the Ingress to be able to access the cluster externally.
3. Wait until all cloud and K8s resources are correctly created
4. Return the ip of the fully running app's frontend access.

### Destroying process:

Similar to deploying, you may add the file `destroy.sh` execution permissions

```bash
$ chmod +x destroy.sh
```

And then run:

```
$ ./destroy.sh
```

This process may take arround 10 minutes and will:

1. Destroy cluster Ingress and Cloud Load Balancer resources
2. Destroy all disk claimed resources of the cluster
3. Destroy all remaining cluster resources
4. Destroy the deployed infraestructure (GKE and Networks)
