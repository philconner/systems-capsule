include:
  - logging/rsyslog_base

{% if grains['os_family'] == 'RedHat' %}
redhat_audit_pkgs:
  pkg.installed:
    - pkgs:
      - audit
      - policycoreutils-python

allow_syslog_read_auditlog:
  selinux.module:
    - name: syslog_read_auditlog
    - module_state: Enabled
    - install: True
    - source: salt://{{tpldir}}/files/syslog_read_auditlog.pp
    - require:
      - pkg: redhat_audit_pkgs
    - watch_in: ensure_rsyslog_current_config
{% endif %}

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
 {% if grains['os_family'] == 'Debian' %}
    - name: /etc/rsyslog.d/send_su-sudo_events.conf
 {% elif grains['os_family'] == 'RedHat' %}
    - name: /etc/rsyslog.d/send_su-sudo-avc_events.conf
 {% endif  %}
    - user: root
    - group: root
    - mode: 0644
    - template: jinja
    - source: salt://{{tpldir}}/files/send_auth-audit_logs.conf
    - require:
      - sls: logging/rsyslog_base
 {% if grains['os_family'] == 'RedHat' %}
      - pkg: redhat_audit_pkgs
 {% endif %}
