# Installing Azure Build Agent for Linux containers

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

### 4. Configure Build Agent

Configure the Azure build agent to use an [unattended config], which will allow us to deploy the agent as an OpenShift pod without manual intervention.
Edit the inline Dockerfile instructions in BuildConfig at [agent.buildconfig.yaml].  Replace the `--url https://dev.azure.com/myOrg` and `--token myToken` variables with your own.
Optionally, replace the `--pool default` and `--agent myOCPAgent` with your own.

```
/opt/app-root/app/config.sh --unattended --url https://dev.azure.com/myOrg --auth pat --token myToken --pool default --agent myOCPAgent --acceptTeeEula
```

Optionally, if you are using Azure Pipelines behind a web proxy, [configure the proxy] as follows.
```
/opt/app-root/app/config.sh --unattended --url https://dev.azure.com/myOrg --auth pat --token myToken --pool default --agent myOCPAgent --acceptTeeEula --proxyurl http://127.0.0.1:8888 --proxyusername "myuser" --proxypassword "mypass"
```

### 5. Create Build Artifacts

Create the following artifacts in OpenShift.  This will build the Azure build agent image from the Dockerfile supplied in `agent.buildconfig.yaml`.

```
$ oc new-project azure-build
$ oc create -f resources/agent.imagestream.yaml
$ oc create -f resources/agent.buildconfig.yaml
```

### 6. Deploy Build Agent

The build agent needs to run as a [privileged container].  To configure this, run the following as cluster-admin:

```
$ oc create sa azure-build-sa -n azure-build
$ oc adm policy add-scc-to-user -z azure-build-sa privileged -n azure-build
```

The `agent.deployment.yaml` file has already been configured to use the `azure-build-sa` serviceaccount.

Now create the deployment which will subsequently create a running build agent pod.

```
$ oc create -f resources/agent.deployment.yaml
```

## Verifying Your Work

To check that the build agent is running, from the Azure DevOps portal, navigate to Project Settings -> Agent pools -> Default (or your own Pool) -> Agents.
You should now see a build agent with Online status.

## License
GPLv3

[set up a Personal Access Token]: https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops#authenticate-with-a-personal-access-token-pat
[unattended config]: https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops#unattended-config
[agent.buildconfig.yaml]: resources/agent.buildconfig.yaml
[configure the proxy]: https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/proxy?view=azure-devops&tabs=unix
[privileged container]: https://access.redhat.com/solutions/6375251
