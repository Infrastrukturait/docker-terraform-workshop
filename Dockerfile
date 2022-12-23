FROM alpine:latest as builder

# Install build dependencies
RUN set -eux \
    && apk --no-cache add \
        curl \
        git \
        unzip

# Get Terraform
ARG TF_VERSION=${TF_VERSION:-default}
RUN set -eux \
    && case "$(uname -s)" in \
            Darwin) ARCH="darwin" ;; \
            Linux)  ARCH="linux"  ;; \
            CYGWIN*|MINGW32*|MSYS*|MINGW*) ARCH="windows" ;; \
            *) ARCH="unknown" ;; \
        esac \
    && case "$(uname -m)" in \
            x86_64) ARCH="${ARCH}_amd64" ;; \
            arm64|aarch64)  ARCH="${ARCH}_arm64" ;; \
            *)    ARCH="${ARCH}_unknown" ;; \
    esac \
    && if [ "${TF_VERSION}" = "default" ]; then \
        TF_VERSION="$(curl -sS -L \
            https://infrastrukturait.github.io/internal-terraform-version/terraform-version)" \
    ; fi \
    && curl -sS -L \
        https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_${ARCH}.zip -o ./terraform.zip \
    && unzip ./terraform.zip \
    && rm -f ./terraform.zip \
    && chmod +x ./terraform \
    && mv ./terraform /usr/bin/terraform

# Get Terragrunt
ARG TG_VERSION=${TG_VERSION:-default}
RUN set -eux \
    && case "$(uname -s)" in \
            Darwin) ARCH="darwin" ;; \
            Linux)  ARCH="linux"  ;; \
            CYGWIN*|MINGW32*|MSYS*|MINGW*) ARCH="windows" ;; \
            *) ARCH="unknown" ;; \
        esac \
    && case "$(uname -m)" in \
            x86_64) ARCH="${ARCH}_amd64" ;; \
            arm64|aarch64)  ARCH="${ARCH}_arm64" ;; \
            *)      ARCH="${ARCH}_unknown" ;; \
    esac \
    && if [ "${TG_VERSION}" = "default" ]; then \
        TG_VERSION="$(curl -sS -L \
            https://infrastrukturait.github.io/internal-terraform-version/terragrunt-version)" \
    ; fi \
    && curl -sS -L \
        https://github.com/gruntwork-io/terragrunt/releases/download/v${TG_VERSION}/terragrunt_${ARCH} \
        -o /usr/bin/terragrunt \
    && chmod +x /usr/bin/terragrunt

# Test binaries
RUN set -eux \
    && terraform --version \
    && terragrunt --version


FROM bash:5.2
LABEL MAINTENER="Rafal Masiarek <rafal@masiarek.pl>"
SHELL ["/usr/local/bin/bash", "-euxo", "pipefail", "-c"]
RUN set -eux \
    && apk --no-cache update \
    && apk --no-cache add python3 py-pip py-setuptools ca-certificates groff less bash git jq file curl \
    && pip --no-cache-dir install awscli \
    && rm -rf /var/cache/apk/*
COPY --from=builder /usr/bin/terraform /usr/bin/terraform
COPY --from=builder /usr/bin/terragrunt /usr/bin/terragrunt

CMD ["/usr/local/bin/bash"]
