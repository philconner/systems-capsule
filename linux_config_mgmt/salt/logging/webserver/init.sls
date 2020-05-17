{% if salt['pkg.version']('nginx') or salt['pkg.version']('apache2') or salt['pkg.version']('httpd') %}

include:
  - logging/rsyslog_base

ensure_rsyslog_current_config:
  service.running:
    - name: rsyslog
    - enable: True
    - restart: True
    - require:
      - sls: logging/rsyslog_base
    - watch:
      - file: rsyslog_d_conf_file

rsyslog_d_conf_file:
  file.managed:
    - name: /etc/rsyslog.d/send_webserver_logs.conf
    - user: root
    - group: root
    - mode: 0644
    - template: jinja
    - source: salt://{{tpldir}}/files/send_webserver_logs.conf
    - require:
      - sls: logging/rsyslog_base

{% endif  %}
