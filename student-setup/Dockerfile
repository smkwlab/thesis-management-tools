FROM ubuntu:22.04

# 必要なツールをインストール
RUN apt-get update && apt-get install -y \
    git \
    curl \
    bash \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI をインストール
RUN type -p curl >/dev/null || (apt update && apt install curl -y) \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt update \
    && apt install gh -y

# セットアップスクリプトをコピー
COPY setup-thesis.sh /usr/local/bin/setup-thesis
RUN chmod +x /usr/local/bin/setup-thesis

# 作業ディレクトリ
WORKDIR /workspace

# Docker環境では手動ブラウザアクセスを前提
ENV DOCKER_ENV=true

# エントリーポイント
ENTRYPOINT ["/usr/local/bin/setup-thesis"]