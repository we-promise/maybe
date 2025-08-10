ARG RUBY_VERSION=3.4.4
FROM ruby:${RUBY_VERSION}-slim-bullseye

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq \
  && apt-get -y install --no-install-recommends \
    apt-utils \
    build-essential \
    curl \
    git \
    imagemagick \
    iproute2 \
    libpq-dev \
    libyaml-dev \
    libyaml-0-2 \
    openssh-client \
    postgresql-client \
    vim \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN gem install bundler foreman

# Install Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y nodejs \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives

WORKDIR /workspace
