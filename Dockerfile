FROM registry.redhat.io/rhel8/dotnet-60-runtime:latest

RUN curl https://vstsagentpackage.azureedge.net/agent/2.206.1/vsts-agent-linux-x64-2.206.1.tar.gz --output /opt/app-root/vsts-agent-linux-x64-2.206.1.tar.gz && \
    tar zxvf /opt/app-root/vsts-agent-linux-x64-2.206.1.tar.gz && \
    chmod -R 775 /opt/app-root/app && \
    # https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops#unattended-config
    /opt/app-root/app/config.sh --unattended --url https://dev.azure.com/myOrg --auth pat --token myToken --pool default --agent myOCPAgent --acceptTeeEula

ENTRYPOINT ["./run-docker.sh"]
