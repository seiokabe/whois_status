FROM ruby:2.3
MAINTAINER sei.okabe <sei.okabe@gmail.com>

# throw errors if Gemfile has been modified since Gemfile.lock

ENV APP_REPO https://github.com/seiokabe/whois_status
ENV APP_DIR  /usr/src/whois_status
ENV APP_CMD  whois.rb

RUN echo "Asia/Tokyo" > /etc/timezone && \
    dpkg-reconfigure --frontend noninteractive tzdata

RUN mkdir -p /usr/src
RUN git clone $APP_REPO $APP_DIR

WORKDIR $APP_DIR
RUN bundle config --global frozen 1
RUN bundle install
RUN curl -s https://www.nexia.jp/note/domain > domain.txt

CMD ["/bin/bash"]

## ONBUILD COPY Gemfile /usr/src/app/
## ONBUILD COPY Gemfile.lock /usr/src/app/
## ONBUILD RUN bundle install
## 
## ONBUILD COPY . /usr/src/app

