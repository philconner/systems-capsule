rsyslog:
  pkg.installed

ensure_rsyslog_correct_config:
  service.running:
    - name: rsyslog
    - enable: True
    - restart: True
    - require:
      - pkg: rsyslog
    - watch:
      - file: ensure_imfile_loaded

ensure_imfile_loaded:
  file.line:
    - name: /etc/rsyslog.conf
    - mode: ensure
    - content: 'module(load="imfile") # provides support for monitoring arbitrary files. Placed by Salt.'
    - before: 'od.+oad.+imuxsock'
    - require:
      - pkg: rsyslog
