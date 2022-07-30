# Installing Azure Build Agent for Linux containers

## Prerequisites

You will need the following:
- OpenShift 4 cluster
- Azure DevOps organization

## Installation

1. Clone this repository as follows:

```
$ git clone https://github.com/kevchu3/azure-buildagent-container.git
```

2. Follow the documentation to [set up a Personal Access Token] in Azure.  Save the personal access token for use later in this installation.

3. Configure the Azure build agent to use an [unattended config], which will allow us to deploy the agent as an OpenShift pod without manual intervention.
Edit the inline Dockerfile instructions in BuildConfig at [agent.buildconfig.yaml].  Replace the `--url https://dev.azure.com/myOrg` and `--token myToken` variables with your own.
Optionally, replace the `--pool default` and `--agent myOCPAgent` with your own.

```
/opt/app-root/app/config.sh --unattended --url https://dev.azure.com/myOrg --auth pat --token myToken --pool default --agent myOCPAgent --acceptTeeEula
```

4. Create the following artifacts in OpenShift.  This will build the Azure build agent image from the Dockerfile supplied in `agent.buildconfig.yaml`.

```
$ oc new-project azure-build-agent
$ oc create -f resources/agent.imagestream.yaml
$ oc create -f resources/agent.buildconfig.yaml
```

5. The build agent needs to run as a [privileged container].  To configure this, run the following as cluster-admin:

```
$ oc project azure-build-agent
$ oc create sa azure-build-sa
$ oc adm policy add-scc-to-user -z azure-build-sa privileged
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
[privileged container]: https://access.redhat.com/solutions/6375251
