FROM alpine:3.18 as builder

# Install build dependencies
RUN set -eux \
    && apk --no-cache add \
        curl \
        git \
        unzip

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
ARG TFDOCS_VERSION=${TFDOCS_VERSION:-latest}
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
ARG INFRACOST_VERSION=${TFDOCS_VERSION:-latest}
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
    && terragrunt --version \
    && terraform-docs --version \
    && infracost --version


FROM docker.io/bash:5-alpine3.18
LABEL MAINTENER="Rafal Masiarek <rafal@masiarek.pl>"
SHELL ["/usr/local/bin/bash", "-c"]
RUN set -eux \
    && apk --no-cache update \
    && apk --no-cache add python3 py-pip py-setuptools ca-certificates groff less bash git jq file curl gomplate openssh-client aws-cli \
    && pip --no-cache-dir install terraform-local pre-commit \
    && echo -e '/usr/bin/curl -s -L https://raw.githubusercontent.com/Infrastrukturait/READMEgen/main/README.md.template |\\\n\t/usr/bin/gomplate -d config=./README.json > ./README.md' > /usr/local/bin/readmegen \
    && echo -e '/usr/bin/aws ${AWS_ENDPOINT_OVERRIDE:+--endpoint-url $AWS_ENDPOINT_OVERRIDE} "$@"' > /usr/local/bin/aws \
    && chmod +x /usr/local/bin/readmegen /usr/local/bin/aws \
    && rm -rf /var/cache/apk/* \
    ;

RUN set -eux \
    && ZSH_IN_DOCKER_VERSION="$(curl -s https://api.github.com/repos/deluan/zsh-in-docker/releases/latest | jq -r .tag_name)" \
    && bash -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
    -p git -p aws -p 'history-substring-search' \
    -a 'bindkey "\$terminfo[kcuu1]" history-substring-search-up' \
    -a 'bindkey "\$terminfo[kcud1]" history-substring-search-down'

ARG TF_VERSION=${TF_VERSION:-latest}
ARG TFENV_VERSION=${TFENV_VERSION:-latest}

ENV TFENV_ROOT /usr/local/lib/tfenv
ENV TFENV_CONFIG_DIR /var/tfenv

ENV TFENV_AUTO_INSTALL true

VOLUME /var/tfenv

RUN set -eux \
    && ln -f /bin/zsh /bin/sh \
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
    && tfenv install $TF_VERSION \
    && tfenv use $TF_VERSION \
    ;

COPY --from=builder /usr/local/bin/terragrunt /usr/local/bin/terragrunt
COPY --from=builder /usr/local/bin/terraform-docs /usr/local/bin/terraform-docs
COPY --from=builder /usr/local/bin/infracost /usr/local/bin/infracost

CMD ["/bin/zsh"]

