FROM ruby:2.6.1

ENV HOME /root
ENV PATH $HOME/.nodenv/bin:$PATH

RUN git clone https://github.com/nodenv/nodenv.git ~/.nodenv
RUN git clone https://github.com/nodenv/node-build.git "/root/.nodenv/plugins/node-build"

RUN eval "$(nodenv init - bash)"
RUN nodenv install 10.24.1

WORKDIR /myapp

COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock

RUN gem install bundler -v 2.3.6

RUN bundle install

# Add a script to be executed every time the container starts.
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# EXPOSE 3000

RUN mkdir -p tmp/sockets
