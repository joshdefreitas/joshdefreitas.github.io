---
title: "Building a Kubernetes-Based Microservices Platform"
author: josh
date: 2025-03-19 10:30:00 +0700
categories: [Project, DevOps]
tags: [Infrastructure, DevOps, CI/CD, k3s, Monitoring]
pin: false
math: true
mermaid: true
image:
  path: https://i.imgur.com/57IPv9g.png
---

# Building a Kubernetes-Based Microservices Platform

# Introduction

As part of my journey into cloud-native development and site reliability engineering (SRE), I built a Kubernetes-based microservices platform. This project focused on container orchestration, service discovery, traffic management, observability, and resilience engineering. The key components included:

- A multi-node Kubernetes cluster (k3s/k8s)
- A service mesh (Istio/Linkerd)
- An observability stack (Prometheus, Grafana, OpenTelemetry)
- Automated CI/CD pipelines (ArgoCD, Flux, or Tekton)
- Chaos engineering experiments (Chaos Mesh/Litmus)

This blog post outlines the architecture, implementation, and key learnings from this project.

# Architecture Overview

Architecture Overview

The platform follows a cloud-native microservices architecture. Here’s a high-level breakdown:

- **Kubernetes Cluster:** A multi-node cluster running k3s/k8s to manage containerized applications.
- **Service Mesh:** Istio or Linkerd handles service-to-service communication, traffic management, and security policies.
- **Observability:** Prometheus and Grafana provide real-time metrics.
- **CI/CD Automation:** ArgoCD/Flux automates application deployment and updates.
- **Chaos Engineering:** Chaos Mesh or Litmus tests system resilience by injecting controlled failures.

### Architecture Diagram

Below is a visual representation of the architecture:

![Architecture Diagram](https://i.imgur.com/yVIVVNI.png)

# Implementation Details

## Phase 1. Setting Up Kubernetes Cluster

I deployed a lightweight **k3s cluster** on a multi-node setup with a master node and two worker nodes. The lightweight nature of k3s made it perfect for this learning project without requiring extensive hardware resources.
Setup steps included:

- Installing k3s on the master node with `curl -sfL https://get.k3s.io | sh -`
- Retrieving the node token from the master with `sudo cat /var/lib/rancher/k3s/server/token`
- Joining worker nodes with `curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 K3S_TOKEN=<TOKEN> sh -`

I faced a few challenges during the setup, particularly with certificate authentication between nodes. The most common issue was token mismatch, which manifested as "token CA hash does not match the Cluster CA certificate hash" errors. Resolving this required using the correct token from /var/lib/rancher/k3s/server/token rather than from the node-token file. To easily connect to my nodes remotely I installed tailscale on each vm.

## Phase 2. Core Platform Components

### Setting Up Local Access

After getting my K3s cluster up and running across my homelab nodes, I needed a way to manage it from my Windows workstation. This step was crucial because it meant I could administer the cluster without having to SSH into the nodes every time.

#### What I Did

I started by installing `kubectl` on my Windows machine by downloading it directly from kubernetes.io. After verifying the checksum (always a good security practice), I created the appropriate config file.

The tricky part was getting the configuration right. I had to:
- Create `~/.kube/config` file on Windows
- Fix YAML formatting errors (those indentations are sensitive!)
- Set `insecure-skip-tls-verify: true` to work with my Tailscale IP
- Point the config to my K3s master node's Tailscale IP address

When I ran `kubectl get nodes`, I could see all three nodes in my cluster responding properly - my master and two worker nodes.

#### Dashboard Setup

For easier visual management, I set up the Kubernetes dashboard by applying the official YAML manifest, creating an admin user, and generating an access token. After starting the proxy with `kubectl proxy`, I could access the full dashboard through my browser.

### Storage Configuration

A quick check with `kubectl get storageclass` showed that K3s already had local-path storage configured as the default - perfect for my homelab needs and ready for deploying apps that need persistent storage.

With these pieces in place, I now have complete control over my homelab Kubernetes cluster from my Windows machine, with both command-line and graphical options for management. This makes a solid foundation for the next phases of my project.

## Phase 3. Service Mesh (Istio) + Obervability Stack

### Installing the Service Mesh
After setting up my K3s cluster and configuring local access, the next step was adding a service mesh layer. I chose Istio for this because it provides enterprise-grade traffic management, security, and observability features without requiring changes to my applications.

#### Installing Istio Components
I started by downloading the Istio command-line tool for Windows and adding it to my PATH. Then I installed Istio with a minimal profile to keep resource usage reasonable for my homelab:`istioctl install --set profile=minimal --set values.pilot.resources.requests.memory=256Mi -y`

The minimal profile didn't include an ingress gateway by default, so I added that separately:`istioctl install --set components.ingressGateways[0].name=istio-ingressgateway --set components.ingressGateways[0].enabled=true -y`

A quick `kubectl get pods -n istio-system` confirmed that both istiod (the control plane) and the ingress gateway were up and running.

#### Enabling Automatic Sidecar Injection
To get the full benefits of the mesh, I enabled automatic sidecar injection for the default namespace: `kubectl label namespace default istio-injection=enabled`

This means any new pods I deploy will automatically get an Istio sidecar proxy without manual configuration - a huge time-saver.

### Observability Stack
One of the biggest advantages of a service mesh is the visibility it provides. I set up a complete observability stack by installing:

```powershell
kubectl apply -f prometheus.yaml
kubectl apply -f grafana.yaml
kubectl apply -f kiali.yaml
```

Now I can access Kiali for service mesh visualization, Grafana for dashboards, and Prometheus for metrics collection using simple port-forward commands when needed.

With this service mesh layer in place, my homelab cluster now has capabilities that mirror what you'd find in production enterprise environments. I can implement advanced deployment strategies, secure service-to-service communication, and gain deep visibility into application traffic patterns.

Here is a visual representation of all my services running in my istio namespace, as shown on my kubernetes dashboard:

![Kubernetes Dashboard](https://i.imgur.com/4LWiipo.png)

## Phase 3: GitOps with ArgoCD

After setting up my Kubernetes cluster, I implemented a GitOps workflow using ArgoCD and Istio. Here's what I did:

1. Created a simple NGINX application with deployment and service manifests in my Git repository

2. Configured ArgoCD to track and deploy my application:
   `kubectl patch application my-apps -n argocd --type=merge -p '{"spec":{"source":{"path":"apps/sample-app"}}}'`

3. Set up Istio resources in a separate folder in my repo:

    Gateway: Defines how traffic enters my cluster
    VirtualService: Routes traffic to my service with path rewriting


4. Created a second ArgoCD application to manage Istio resources separately:
    `bashCopykubectl apply -f argocd-istio-application.yaml`

5. Enabled Istio sidecar injection and restarted my deployment:
    `bashCopykubectl label namespace default istio-injection=enabled`

6. Accessed my application through the Istio gateway: http://master-node-ip/sample-app

The key benefit of this approach is separation of concerns - my application configs and networking configs are tracked separately in Git but deployed automatically by ArgoCD. When I push changes to either repo, ArgoCD automatically syncs them to my cluster, following true GitOps principles.

Here is a representation of my deployment in ArgoCD dashboard:

![Argo Dashboard](https://i.imgur.com/PUQsdfG.png)

## Phase 4: Deploy Sample Microservices