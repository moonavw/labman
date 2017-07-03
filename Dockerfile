FROM moonavw/rails:latest

WORKDIR /usr/src/app
COPY Gemfile .

ENV RAILS_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true

RUN bundle install --without development test
COPY . .

RUN echo "SECRET_KEY_BASE: "$(rake secret) > config/application.yml

RUN rails assets:precompile

EXPOSE 3000

CMD ["./bin/rails", "server"]
