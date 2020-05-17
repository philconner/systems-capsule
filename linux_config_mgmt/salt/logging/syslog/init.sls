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
    - name: /etc/rsyslog.d/send_all_syslog.conf
    - user: root
    - group: root
    - mode: 0644
    - template: jinja
    - source: salt://{{tpldir}}/files/send_all_syslog.conf
    - require:
      - sls: logging/rsyslog_base
