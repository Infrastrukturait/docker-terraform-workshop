FROM alpine:3.16 as builder

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
    && mv ./terraform /usr/local/bin/terraform

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
        -o /usr/local/bin/terragrunt \
    && chmod +x /usr/local/bin/terragrunt

# Get Terraform docs
ENV TFDOCS_VERSION=0.16.0
RUN set -eux \
    && case "$(uname -s)" in \
            Darwin) ARCH="darwin" ;; \
            Linux)  ARCH="linux"  ;; \
            CYGWIN*|MINGW32*|MSYS*|MINGW*) ARCH="windows" ;; \
            *) ARCH="unknown" ;; \
        esac \
    && case "$(uname -m)" in \
            x86_64) ARCH="${ARCH}-amd64" ;; \
            arm64|aarch64)  ARCH="${ARCH}-arm64" ;; \
            *)      ARCH="${ARCH}-unknown" ;; \
    esac \
    && curl -Lo ./terraform-docs.tar.gz https://github.com/terraform-docs/terraform-docs/releases/download/v${TFDOCS_VERSION}/terraform-docs-v${TFDOCS_VERSION}-${ARCH}.tar.gz \
    && tar -xzf terraform-docs.tar.gz \
    && chmod +x terraform-docs \
    && mv terraform-docs /usr/local/bin/terraform-docs \
    ;

# Get Terraform docs
ENV INFRACOST_VERSION=0.10.15
RUN set -eux \
    && case "$(uname -s)" in \
            Darwin) ARCH="darwin" ;; \
            Linux)  ARCH="linux"  ;; \
            CYGWIN*|MINGW32*|MSYS*|MINGW*) ARCH="windows" ;; \
            *) ARCH="unknown" ;; \
        esac \
    && case "$(uname -m)" in \
            x86_64) ARCH="${ARCH}-amd64" ;; \
            arm64|aarch64)  ARCH="${ARCH}-arm64" ;; \
            *)      ARCH="${ARCH}-unknown" ;; \
    esac \
    && curl -Lo ./infracost.tar.gz https://github.com/infracost/infracost/releases/download/v${INFRACOST_VERSION}/infracost-${ARCH}.tar.gz  \
    && tar -xzf infracost.tar.gz \
    && chmod +x infracost-${ARCH} \
    && mv infracost-${ARCH} /usr/local/bin/infracost \
    ;

# Test binaries
RUN set -eux \
    && terraform --version \
    && terragrunt --version \
    && terraform-docs --version \
    && infracost --version


FROM alpine:3.16
LABEL MAINTENER="Rafal Masiarek <rafal@masiarek.pl>"
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.5/zsh-in-docker.sh)" -- \
    -p git -p ssh-agent -p 'history-substring-search' \
    -a 'bindkey "\$terminfo[kcuu1]" history-substring-search-up' \
    -a 'bindkey "\$terminfo[kcud1]" history-substring-search-down'

RUN set -eux \
    && apk --no-cache update \
    && apk --no-cache add python3 py-pip py-setuptools ca-certificates groff less bash git jq file curl gomplate \
    && pip --no-cache-dir install awscli \
    && echo -e ' #!/usr/bin/env bash\n/usr/bin/curl -s -L https://raw.githubusercontent.com/Infrastrukturait/READMEgen/main/README.md.template |\\\n\t/usr/bin/gomplate -d config=./README.json > ./README.md' > /usr/local/bin/readmegen \
    && chmod +x /usr/local/bin/readmegen \
    && rm -rf /var/cache/apk/* \
    ;

ARG TFENV_VERSION=3.0.0
ENV TFENV_ROOT /usr/local/lib/tfenv
ENV TFENV_CONFIG_DIR /var/tfenv

VOLUME /var/tfenv

RUN set -eux \
    && TFENV_TERRAFORM_VERSION="$(curl -sS -L \
            https://infrastrukturait.github.io/internal-terraform-version/terraform-version)" \
    && wget -O /tmp/tfenv.tar.gz "https://github.com/tfutils/tfenv/archive/refs/tags/v${TFENV_VERSION}.tar.gz" \
    && tar -C /tmp -xf /tmp/tfenv.tar.gz \
    && mv "/tmp/tfenv-${TFENV_VERSION}/bin"/* /usr/local/bin/ \
    && mkdir -p /usr/local/lib/tfenv \
    && mv "/tmp/tfenv-${TFENV_VERSION}/lib" /usr/local/lib/tfenv/ \
    && mv "/tmp/tfenv-${TFENV_VERSION}/libexec" /usr/local/lib/tfenv/ \
    && mkdir -p /usr/local/share/licenses \
    && mv "/tmp/tfenv-${TFENV_VERSION}/LICENSE" /usr/local/share/licenses/tfenv \
    && rm -rf /tmp/tfenv* \
    && case "$(uname -m)" in \
            x86_64) TFENV_ARCH=amd64 ;; \
            arm64|aarch64)  TFENV_ARCH=arm64 ;; \
            *)    TFENV_ARCH=unknown ;; \
    esac \
    && tfenv install $TFENV_TERRAFORM_VERSION \
    && tfenv use $TFENV_TERRAFORM_VERSION \
    ;


COPY --from=builder /usr/local/bin/terragrunt /usr/local/bin/terragrunt
COPY --from=builder /usr/local/bin/terraform-docs /usr/local/bin/terraform-docs
COPY --from=builder /usr/local/bin/infracost /usr/local/bin/infracost
