haven — documentation
=====================

Configuration repository managed by `strata <https://github.com/huybrechtsxyz/strata>`_.

**haven** is the infrastructure and application configuration for the family platform:
a two-node Hetzner setup (Core VPS on Docker Compose + Workload VPS on k3s),
with Infomaniak kSuite for email and files, and INWX for DNS.

.. toctree::
   :maxdepth: 2
   :caption: Getting Started

   GUIDE
   design

.. toctree::
   :maxdepth: 2
   :caption: Deployment

   hetzner
   inwx
   terraform
   github

.. toctree::
   :maxdepth: 2
   :caption: Core Services

   authentik
   infisical
   bitwarden
   portainer

.. toctree::
   :maxdepth: 2
   :caption: Collaboration & Email

   infomaniak
   borgbackup

.. toctree::
   :maxdepth: 2
   :caption: Monitoring

   healthchecks-io
   uptimerobot
   wud

.. toctree::
   :maxdepth: 1
   :caption: Reference

   genindex
