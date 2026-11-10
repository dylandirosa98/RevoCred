FROM searxng/searxng@sha256:bed9946e14c009da4efdb477545eb48eb8d1d87af25e9738ff8b8584cb89a311
COPY settings.yml /revo-search-settings.yml
ENV SEARXNG_SETTINGS_PATH=/revo-search-settings.yml
COPY start.sh /revo-search-start.sh
ENTRYPOINT ["/bin/sh", "/revo-search-start.sh"]
