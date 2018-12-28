FROM php:7.2-fpm-alpine

ARG BUILD_DATE
ARG VCS_REF

LABEL maintainer="John Lamp" \
  org.label-schema.name="ownCloud" \
  org.label-schema.description="Minimal ownCloud docker image based on Alpine Linux." \
  org.label-schema.build-date=$BUILD_DATE \
  org.label-schema.vcs-ref=$VCS_REF \
  org.label-schema.vcs-url="@TODO" \
  org.label-schema.schema-version="1.0"

ARG OWNCLOUD_GPG="E303 6906 AD9F 3080 7351  FAC3 2D5D 5E97 F697 8A26"
ARG OWNCLOUD_VERSION=10.0.10
ARG UID=1503
ARG GID=1503

RUN set -ex \
  # Add user for owncloud
  && addgroup -g ${GID} owncloud \
  && adduser -u ${UID} -h /opt/owncloud -H -G owncloud -s /sbin/nologin -D owncloud \
  # Install
  && apk update \
  && apk upgrade \
  && apk add \
  alpine-sdk \
  autoconf \
  bash \
  freetype \
  freetype-dev \
  gnupg \
  icu-dev \
  icu-libs \
  libjpeg-turbo \
  libjpeg-turbo-dev \
  libldap \
  libmcrypt \
  libmcrypt-dev \
  libmemcached \
  libmemcached-dev \
  libpng \
  libpng-dev \
  libzip \
  libzip-dev \
  nginx \
  openldap-dev \
  openssl \
  pcre \
  pcre-dev \
  postgresql-dev \
  postgresql-libs \
  samba-client \
  sudo \
  supervisor \
  tar \
  tini \
  wget \
# PHP Extensions
  && docker-php-ext-configure gd --with-freetype-dir=/usr --with-png-dir=/usr --with-jpeg-dir=/usr \
  && docker-php-ext-configure ldap \
  && docker-php-ext-configure zip --with-libzip=/usr \
  && docker-php-ext-install gd exif intl mbstring ldap mysqli opcache pcntl pdo_mysql pdo_pgsql pgsql zip \
  && pecl install APCu-5.1.12 \
  && pecl install mcrypt-1.0.1 \
  && pecl install memcached-3.0.4 \
  && pecl install redis-4.1.1 \
  && docker-php-ext-enable apcu mcrypt memcached redis \
# Remove dev packages
  && apk del \
    alpine-sdk \
    autoconf \
    freetype-dev \
    icu-dev \
    libmcrypt-dev \
    libmemcached-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    openldap-dev \
    pcre-dev \
    postgresql-dev \
  && rm -rf /var/cache/apk/* \
  && mkdir -p /opt/owncloud \
# Download Owncloud
  && cd /tmp \
  && OWNCLOUD_TARBALL="owncloud-${OWNCLOUD_VERSION}.tar.bz2" \
  && wget -q https://download.owncloud.org/community/${OWNCLOUD_TARBALL} \
  && wget -q https://download.owncloud.org/community/${OWNCLOUD_TARBALL}.sha256 \
  && wget -q https://download.owncloud.org/community/${OWNCLOUD_TARBALL}.asc \
  && wget -q https://owncloud.org/owncloud.asc \
# Verify checksum
  && echo "Verifying both integrity and authenticity of ${OWNCLOUD_TARBALL}..." \
  && CHECKSUM_STATE=$(echo -n $(sha256sum -c ${OWNCLOUD_TARBALL}.sha256) | tail -c 2) \
  && if [ "${CHECKSUM_STATE}" != "OK" ]; then echo "Warning! Checksum does not match!" && exit 1; fi \
  && gpg --import owncloud.asc \
  && FINGERPRINT="$(LANG=C gpg --verify ${OWNCLOUD_TARBALL}.asc ${OWNCLOUD_TARBALL} 2>&1 | sed -n "s#Primary key fingerprint: \(.*\)#\1#p")" \
  && if [ -z "${FINGERPRINT}" ]; then echo "Warning! Invalid GPG signature!" && exit 1; fi \
  && if [ "${FINGERPRINT}" != "${OWNCLOUD_GPG}" ]; then echo "Warning! Wrong GPG fingerprint!" && exit 1; fi \
  && echo "All seems good, now unpacking ${OWNCLOUD_TARBALL}..." \
# Extract
  && tar xjf ${OWNCLOUD_TARBALL} --strip-components=1 -C /opt/owncloud \
  && rm -rf /tmp/* /root/.gnupg \
# Wipe excess directories
  && rm -rf /var/www/*

COPY root /

RUN chmod +x /usr/local/bin/run.sh /usr/local/bin/occ /etc/periodic/15min/owncloud

VOLUME ["/data"]

EXPOSE 80

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/run.sh"]
