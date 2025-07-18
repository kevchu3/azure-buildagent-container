# Hosting Azure Build Agent in OpenShift

## Prerequisites

You will need the following:
- OpenShift 4 cluster
- Azure DevOps organization

## Installation

### 1. Clone this repository

```
$ git clone https://github.com/kevchu3/azure-buildagent-container.git
```

### 2. Set up a Personal Access Token

Follow the documentation to [set up a Personal Access Token] in Azure.  Save the personal access token for use later in this installation.

### 3. Configure Agent Pool

Create a new Agent Pool or configure an existing Agent Pool by navigating to Project Settings -> Agent pools.

To create a new Agent Pool, navigate to Project Settings -> Agent pools, and Add agent pool.

- Pool to link: New
- Pool type: Self-hosted
- Name: <your agent pool name>
- Pipeline permissions: Grant access permission to all pipelines

Verify from the pool's Security tab that you are assigned as an Administrator to the pool.

Otherwise, configure an existing Agent Pool.  Confirm the following:
- Pipeline permissions: Grant access permission to all pipelines
- Verify from the pool's Security tab that you are assigned as an Administrator to the pool.

### 4. Create Build Artifacts

Create a new project in OpenShift.  For our example, we have used `azure-build`.  The included [start.sh] wrapper script configures and runs the container, copy this as a ConfigMap to the project:
```
$ oc new-project azure-build
$ oc create cm start-sh --from-file=start.sh=resources/start.sh
```

Create [imagestream] and [buildconfig] artifacts to build the Azure build agent image.  Configured triggers will start a new build automatically.

```
$ oc create -f resources/imagestream.yaml -f resources/buildconfig.yaml
```

Optionally, determine the latest published agent release.  Navigate to [Azure Pipelines Agent] and check the page for the highest version number listed.  Note the Agent download URL for Linux x64.

Configure the `AZP_AGENT_PACKAGE_LATEST_URL` environment variable in the BuildConfig with the desired Agent download URL, and build a new agent image:

```
$ oc set env bc/azure-build-agent AZP_AGENT_PACKAGE_LATEST_URL=https://download.agent.dev.azure.com/agent/4.258.1/vsts-agent-linux-x64-4.258.1.tar.gz
$ oc start-build azure-build-agent
```

### 5. Configure Builder as Rootless User

As a security best practice, pods should be run as a rootless user.  There are several methods to accomplish this, and we have opted to lock down privileges by [creating a new SecurityContextConstraint] named `nonroot-builder` for the Azure DevOps service account for our builder pods.

As cluster-admin, create a serviceaccount for the build agent, a [nonroot-builder SCC], and apply the SCC to the serviceaccount:
```
$ oc create sa azure-build-sa
$ oc create -f resources/nonroot-builder.yaml
$ oc adm policy add-scc-to-user nonroot-builder -z azure-build-sa
```

### 6. Configure Deployment

The Azure build agent is configured to use an [unattended config], which will allow us to deploy the agent as an OpenShift pod without manual intervention.

Configure the Azure DevOps credentials as a Secret named azdevops, replacing the values for environment variables with your own.  For example:

```
$ oc create secret generic azdevops \
  --from-literal=AZP_URL=https://dev.azure.com/yourOrg \
  --from-literal=AZP_TOKEN=YourPAT \
  --from-literal=AZP_POOL=NameOfYourPool
```

Optionally, for a [proxy configuration], also create a Secret named azproxy, replacing environment variables with your own.  The `NO_PROXY` proxy bypass configuration can be extracted from the [cluster-wide proxy].  For example:

```
$ oc get proxy -o jsonpath='{.items[0].status.noProxy}'
$ oc create secret generic azproxy \
  --from-literal=AZP_PROXY_URL=http://192.168.0.1:8888 \
  --from-literal=AZP_PROXY_USERNAME=myuser \
  --from-literal=AZP_PROXY_PASSWORD=mypass \
  --from-literal=HTTP_PROXY=http://myuser:mypass@192.168.0.1:8888 \
  --from-literal=HTTPS_PROXY=https://myuser:mypass@192.168.0.1:8888 \
  --from-literal=NO_PROXY=.cluster.local,.ec2.internal,.svc,10.0.0.0/16,10.128.0.0/14,127.0.0.1,169.254.169.254,172.30.0.0/16,api-int.example.com,example.com,localhost
```

Unauthenticated proxy can be defined as follows:

```
$ oc create secret generic azproxy \
  --from-literal=AZP_PROXY_URL=http://192.168.0.1:8888 \
  --from-literal=HTTP_PROXY=http://192.168.0.1:8888 \
  --from-literal=HTTPS_PROXY=https://192.168.0.1:8888 \
  --from-literal=NO_PROXY=.cluster.local,.ec2.internal,.svc,10.0.0.0/16,10.128.0.0/14,127.0.0.1,169.254.169.254,172.30.0.0/16,api-int.example.com,example.com,localhost
```

See the following table for a description of the above [environment variables]:

| Environment variable     | Secret   | Description              |
| ------------------------ | -------- | ------------------------ |
| AZP_URL                  | azdevops | The URL of the Azure DevOps or Azure DevOps Server instance. |
| AZP_TOKEN                | azdevops | Personal Access Token (PAT) with Agent Pools (read, manage) scope, created by a user who has permission to configure agents, at `AZP_URL`. |
| AZP_POOL                 | azdevops | Agent pool name (default value: `Default`). |
| AZP_PROXY_URL            | azproxy  | (Optional) Proxy URL for Agent to talk to Azure DevOps. |
| AZP_PROXY_USERNAME       | azproxy  | (Optional) Proxy username for Agent. |
| AZP_PROXY_PASSWORD       | azproxy  | (Optional) Proxy password for Agent. |
| HTTP_PROXY               | azproxy  | (Optional) Configure container-wide proxy settings using `HTTP_PROXY` environment variable. |
| HTTPS_PROXY              | azproxy  | (Optional) Configure container-wide proxy settings using `HTTPS_PROXY` environment variable. |
| NO_PROXY                 | azproxy  | (Optional) Configure container-wide proxy bypass settings using `NO_PROXY` environment variable. |

### 7. Deploy Build Agent

Create the [deployment] which will subsequently create a running build agent pod.

```
$ oc create -f resources/deployment.yaml
```

Optionally, you will need to perform these additional steps if you require a [privately signed CA for your proxy]:

a. [Modify the default Proxy object] to include your privately signed CA certificates.

b. [Inject the privately signed CA] into your deployment.  You will deploy the [agent-with-custom-ca-deployment.yaml] file instead of the one above:

```
$ oc create -f resources/agent-with-custom-ca-deployment.yaml
```

## Verifying Your Work

To check that the build agent is running, from the Azure DevOps portal, navigate to Project Settings -> Agent pools -> Default (or your own Pool) -> Agents.
You should now see a build agent with Online status.

Optionally, you can scale up pod replicas which will deploy additional agents.

## License
GPLv3

[set up a Personal Access Token]: https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops#authenticate-with-a-personal-access-token-pat
[start.sh]: resources/start.sh
[imagestream]: resources/imagestream.yaml
[buildconfig]: resources/buildconfig.yaml
[Azure Pipelines Agent]: https://github.com/Microsoft/azure-pipelines-agent/releases
[creating a new SecurityContextConstraint]: https://www.redhat.com/sysadmin/rootless-podman-jenkins-openshift
[nonroot-builder SCC]: resources/nonroot-builder.yaml
[unattended config]: https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops#unattended-config
[proxy configuration]: https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/proxy?view=azure-devops&tabs=unix
[cluster-wide proxy]: https://docs.openshift.com/container-platform/latest/networking/enable-cluster-wide-proxy.html
[environment variables]: https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/docker?view=azure-devops#environment-variables
[deployment]: resources/deployment.yaml
[privately signed CA for your proxy]: https://docs.openshift.com/container-platform/latest/networking/configuring-a-custom-pki.html
[Modify the default Proxy object]: https://docs.openshift.com/container-platform/latest/security/certificates/updating-ca-bundle.html#ca-bundle-replacing_updating-ca-bundle
[Inject the privately signed CA]: https://docs.openshift.com/container-platform/latest/networking/configuring-a-custom-pki.html#certificate-injection-using-operators_configuring-a-custom-pki
[agent-with-custom-ca-deployment.yaml]: resources/agent-with-custom-ca-deployment.yaml
