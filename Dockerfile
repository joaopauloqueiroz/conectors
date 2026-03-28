FROM ruby:3.3.6-slim

WORKDIR /app

RUN apt-get update -y && apt-get install -y --no-install-recommends \
  build-essential \
  && rm -rf /var/lib/apt/lists/*

COPY Gemfile ./
RUN bundle install --without development test

COPY . .

EXPOSE 9292

CMD ["bundle", "exec", "puma", "config.ru", "-p", "9292", "-e", "production"]
