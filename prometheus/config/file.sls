# -*- coding: utf-8 -*-
# vim: ft=sls

{%- set tplroot = tpldir.split('/')[0] %}
{%- from tplroot ~ "/map.jinja" import prometheus as p with context %}
{%- from tplroot ~ "/libtofs.jinja" import files_switch with context %}

{%- set sls_archive_install = tplroot ~ '.archive.install' %}
{%- set sls_package_install = tplroot ~ '.package.install' %}
{%- set sls_config_users = tplroot ~ '.config.users' %}

include:
  - {{ sls_archive_install if p.pkg.use_upstream_archive else sls_package_install }}
  - {{ sls_config_users }}

prometheus-config-file-etc-file-directory:
  file.directory:
    - name: {{ p.dir.etc }}
    - makedirs: True
            {%- if grains.os != 'Windows' %}
    - mode: '0755'
    - user: {{ p.identity.rootuser }}
    - group: {{ p.identity.rootgroup }}
            {%- endif %}
    - require:
      - sls: {{ sls_archive_install if p.pkg.use_upstream_archive else sls_package_install }}

    # This loop manages the main config file for each component
    {%- for name in p.wanted.component %}
        {%- if 'config' in p.pkg.component[name] and p.pkg.component[name]['config'] %}

prometheus-config-file-{{ name }}-file-managed:
  file.managed:
    - name: {{ p.dir.etc }}{{ p.div }}{{ name }}.yml
    - source: {{ files_switch(['config.yml.jinja'],
                              lookup='prometheus-config-file-' ~ name ~ '-file-managed'
                 )
              }}
    - makedirs: True
    - template: jinja
            {%- if grains.os != 'Windows' %}
    - mode: 644
    - user: {{ name }}
    - group: {{ name }}
            {%- endif %}
    - context:
        config: {{ p.pkg.component[name]['config']|json }}
    - require:
      - file: prometheus-config-file-etc-file-directory
      - user: prometheus-config-users-install-{{ name }}-user-present
      - group: prometheus-config-users-install-{{ name }}-group-present
    {%- if 'service' in p.pkg.component[name] and p.pkg.component[name]['service'] %}
    - watch_in:
      - service: prometheus-service-running-{{ name }}
      - restart: true
    {%- endif %}

        {%- endif %}
    {%- endfor %}

    # This loop manages other config files, like `rules_files`
    {%- for ef in p.extra_files %}
      {%- set name = p.extra_files[ef]['file'] | default(ef) %}
      {%- set component = p.extra_files[ef]['component'] | default('prometheus') %}

prometheus-config-file-{{ ef }}-file-managed:
  file.managed:
    {%- if grains.os != 'Windows' and name.startswith("/") %}
    - name: {{ name }}
    {%- else %}
    - name: {{ p.dir.etc }}{{ p.div }}{{ name }}.yml
    {%- endif %}
    - source: {{ files_switch(['config.yml.jinja'],
                              lookup='prometheus-config-file-' ~ ef ~ '-file-managed'
                 )
              }}
    - makedirs: True
    - template: jinja
            {%- if grains.os != 'Windows' %}
    - mode: 644
    - user: {{ component }}
    - group: {{ component }}
            {%- endif %}
    - context:
        config: {{ p.extra_files[ef]['config'] }}
    - require:
      - file: prometheus-config-file-etc-file-directory
      - user: prometheus-config-users-install-{{ component }}-user-present
      - group: prometheus-config-users-install-{{ component }}-group-present
    - watch_in:
      - service: prometheus-service-running-{{ component }}

    {%- endfor %}
