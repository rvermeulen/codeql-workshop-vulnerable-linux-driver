FROM debian
ARG CODEQL_VERSION=v2.13.0

RUN apt-get update && apt-get upgrade -y
RUN apt-get install build-essential linux-headers-amd64 curl unzip -y

RUN useradd -ms /bin/bash codeql

USER codeql
WORKDIR /home/codeql
RUN curl -L https://github.com/github/codeql-cli-binaries/releases/download/$CODEQL_VERSION/codeql-linux64.zip -o codeql-linux64.zip && unzip codeql-linux64.zip

ENTRYPOINT ["/home/codeql/codeql/codeql"]
