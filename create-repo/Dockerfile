FROM alpine:latest

# 必要なツールをインストール
RUN apk add --no-cache \
    git \
    curl \
    bash \
    ca-certificates \
    unzip

# GitHub CLI をインストール
RUN ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') && \
    LATEST_VERSION=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep tag_name | cut -d'"' -f4 | tr -d 'v') && \
    curl -fsSL "https://github.com/cli/cli/releases/latest/download/gh_${LATEST_VERSION}_linux_${ARCH}.tar.gz" \
    | tar -xz -C /tmp && \
    mv "/tmp/gh_${LATEST_VERSION}_linux_${ARCH}/bin/gh" /usr/local/bin/ && \
    rm -rf /tmp/gh_*

# 作業ディレクトリを先に設定
WORKDIR /workspace

# セットアップスクリプトをコピー
COPY main.sh ./
RUN chmod +x main.sh

# Docker環境では手動ブラウザアクセスを前提
ENV DOCKER_ENV=true

# エントリーポイント
ENTRYPOINT ["./main.sh"]