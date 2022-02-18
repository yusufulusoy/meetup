### Build and install packages
FROM python:3.10 as build-python

RUN apt-get -y update \
  && apt-get install -y gettext \
  # Cleanup apt cache
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements_dev.txt /app/
WORKDIR /app
RUN pip install -r requirements_dev.txt

### Final image
FROM python:3.10-slim

ARG API_USER
RUN groupadd -r ${API_USER} && useradd -r -g ${API_USER} ${API_USER}

RUN apt-get update \
  && apt-get install -y \
  libcairo2 \
  libgdk-pixbuf2.0-0 \
  liblcms2-2 \
  libopenjp2-7 \
  libpango-1.0-0 \
  libpangocairo-1.0-0 \
  libssl1.1 \
  libtiff5 \
  libwebp6 \
  libxml2 \
  libpq5 \
  shared-mime-info \
  mime-support \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app/media /app/static \
  && chown -R ${API_USER}:${API_USER} /app/

COPY --from=build-python /usr/local/lib/python3.10/site-packages/ /usr/local/lib/python3.10/site-packages/
COPY --from=build-python /usr/local/bin/ /usr/local/bin/
COPY . /app
WORKDIR /app

ARG STATIC_URL
ENV STATIC_URL ${STATIC_URL:-/static/}
RUN SECRET_KEY=dummy STATIC_URL=${STATIC_URL} python3 manage.py collectstatic --no-input

# RUN python3 manage.py makemigrations --no-input
# RUN python3 manage.py migrate --no-input
# RUN python3 manage.py createsu

EXPOSE ${API_WEB_PORT}
ENV PYTHONUNBUFFERED 1

CMD ["gunicorn", "--bind", ":${API_WEB_PORT}", "--workers", "4", "--worker-class", "meetup.asgi.gunicorn_worker.UvicornWorker", "meetup.asgi:application"]
