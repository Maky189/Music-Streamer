FROM postgres:16-alpine

RUN apk add --no-cache python3

COPY 00-create-schema.sql /docker-entrypoint-initdb.d/
COPY generate-seed-data.py /usr/local/bin/generate-seed-data.py
COPY entrypoint-script.sh /usr/local/bin/entrypoint-script.sh

RUN chmod +x /usr/local/bin/entrypoint-script.sh /usr/local/bin/generate-seed-data.py

ENV MUSIC_DIR=/music

ENTRYPOINT ["/usr/local/bin/entrypoint-script.sh"]
CMD ["postgres"]
