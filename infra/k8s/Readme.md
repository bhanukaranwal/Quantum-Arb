Kubernetes Configuration - Helm & IstioThis directory contains the Kubernetes manifests, Helm charts, and service mesh configurations (Istio/Linkerd) for deploying the QuantumArb 2.0 microservices.Structure/charts: Contains Helm charts for each microservice (core-services, ml-pipeline, etc.). Each chart defines the deployments, services, configmaps, and other Kubernetes resources required./policies: Holds network policies and service mesh configurations. This includes Istio VirtualService, DestinationRule, and Gateway resources to manage traffic routing, canary deployments, and mTLS security./base: Common Kubernetes manifests and base configurations that are shared across multiple services.DeploymentServices are deployed via Helm. To deploy or upgrade a service, use the following commands:# Add the repository (if applicable)
helm repo add quantum-arb ...

# Install or upgrade a chart
helm upgrade --install [release-name] ./charts/[service-name] -f ./charts/[service-name]/values.yaml
The CI/CD pipeline in infra/ci_cd automates this process using GitOps principles with ArgoCD.
