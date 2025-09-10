FROM ruby:2.6.1

# Update sources list to use archive repositories for Debian Stretch
RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security stretch/updates main" >> /etc/apt/sources.list && \
    echo "Acquire::Check-Valid-Until false;" > /etc/apt/apt.conf.d/90ignore-release-date && \
    echo "Acquire::AllowInsecureRepositories true;" >> /etc/apt/apt.conf.d/90ignore-release-date && \
    echo "Acquire::AllowDowngradeToInsecureRepositories true;" >> /etc/apt/apt.conf.d/90ignore-release-date

# Install system dependencies
RUN apt-get update && apt-get install -y --allow-unauthenticated \
    curl \
    sqlite3 \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /myapp

COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock

RUN gem install bundler -v 2.3.6
RUN bundle install

# Add entrypoint script
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 3000

RUN mkdir -p tmp/sockets tmp/pids