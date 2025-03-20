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

## Introduction

As part of my journey into cloud-native development and site reliability engineering (SRE), I built a Kubernetes-based microservices platform. This project focused on container orchestration, service discovery, traffic management, observability, and resilience engineering. The key components included:

- A multi-node Kubernetes cluster (k3s/k8s)
- A service mesh (Istio/Linkerd)
- An observability stack (Prometheus, Grafana, OpenTelemetry)
- Automated CI/CD pipelines (ArgoCD, Flux, or Tekton)
- Chaos engineering experiments (Chaos Mesh/Litmus)

This blog post outlines the architecture, implementation, and key learnings from this project.

## Architecture Overview

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

## Implementation Details

### 1. Setting Up Kubernetes Cluster

I deployed a lightweight **k3s cluster** on a multi-node setup with a master node and two worker nodes. The lightweight nature of k3s made it perfect for this learning project without requiring extensive hardware resources.
Setup steps included:

- Installing k3s on the master node with `curl -sfL https://get.k3s.io | sh -`
- Retrieving the node token from the master with `sudo cat /var/lib/rancher/k3s/server/token`
- Joining worker nodes with `curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 K3S_TOKEN=<TOKEN> sh -`

I faced a few challenges during the setup, particularly with certificate authentication between nodes. The most common issue was token mismatch, which manifested as "token CA hash does not match the Cluster CA certificate hash" errors. Resolving this required using the correct token from /var/lib/rancher/k3s/server/token rather than from the node-token file. To easily connect to my nodes remotely I installed tailscale on each vm.

### 2. Core Platform Components

After successfully setting up my k3s cluster, I needed to establish essential platform components. This phase focused on configuring access, deploying management tools, and setting up foundational services.

#### Setting Up Local Access

First, I needed to configure my local workstation to communicate with the cluster. Working directly from the control plane node quickly became cumbersome, especially when writing YAML manifests or running multiple commands.

I copied the kubeconfig from the master node:

```bash
# From control plane node
cat /etc/rancher/k3s/k3s.yaml
```