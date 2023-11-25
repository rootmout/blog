FROM ubuntu:22.04 as BUILD

# install syntax highlighting
RUN apt-get -y update
RUN apt-get install -y python3-pygments

# install hugo
ENV HUGO_VERSION=0.93.2
ADD https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz /tmp/
RUN tar -xf /tmp/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz -C /usr/local/bin/

# build site
COPY src /source
RUN hugo --source=/source/ --destination=/public/

FROM nginx:1.25.3-alpine
RUN apk --update add curl bash
RUN rm /etc/nginx/conf.d/default.conf
COPY modules/blog.kelbert.fr.conf /etc/nginx/conf.d/blog.kelbert.fr.conf
COPY --from=BUILD /public/ /usr/share/nginx/html/
EXPOSE 80 443
