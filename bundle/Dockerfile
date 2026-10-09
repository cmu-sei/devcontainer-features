# The base Python 3.14 is reused by LiteLLM, Open Terminal, SearXNG, and supervisor
FROM mcr.microsoft.com/devcontainers/python:3.14-trixie

# Root CAs for a TLS-inspecting proxy (e.g. Zscaler): drop the *.crt files in
# .devcontainer/certs/. A feature installer can't see the project, so they are copied into
# the image here; the custom-certs feature then trusts them, and devcontainer.json's
# overrideFeatureInstallOrder runs it before any other feature downloads anything.
COPY certs/ /usr/local/share/custom-certs/
