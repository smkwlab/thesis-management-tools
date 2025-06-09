FROM ghcr.io/cli/cli:latest

# 必要なツールをインストール
RUN apt-get update && apt-get install -y \
    git \
    curl \
    bash \
    && rm -rf /var/lib/apt/lists/*

# セットアップスクリプトをコピー
COPY setup-thesis.sh /usr/local/bin/setup-thesis
RUN chmod +x /usr/local/bin/setup-thesis

# 作業ディレクトリ
WORKDIR /workspace

# エントリーポイント
ENTRYPOINT ["/usr/local/bin/setup-thesis"]