FROM ruby:3.2

WORKDIR /app

# Ensure stdout/stderr are unbuffered
ENV PYTHONUNBUFFERED=1
ENV RUBYOPT=-W0

COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .

# Explicitly tell Ruby to flush output
CMD ["ruby", "-W0", "pinger.rb"]