FROM alpine:3.19

RUN apk add --no-cache mariadb-client gzip findutils coreutils

WORKDIR /app

COPY backup.sh .
RUN chmod +x backup.sh

CMD ["./backup.sh"]
