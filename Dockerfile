FROM registry.redhat.io/rhel8/dotnet-60-runtime:latest

RUN curl https://vstsagentpackage.azureedge.net/agent/2.206.1/vsts-agent-linux-x64-2.206.1.tar.gz --output /opt/app-root/vsts-agent-linux-x64-2.206.1.tar.gz && \
    tar zxvf /opt/app-root/vsts-agent-linux-x64-2.206.1.tar.gz && \
    chmod +x run-docker.sh

ENTRYPOINT ["./run-docker.sh"]
