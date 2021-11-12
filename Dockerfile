FROM alpine:latest

# make ash source ashrc so we can warn user about being in wrapper container
ENV ENV=/etc/ashrc

RUN apk add --update --no-cache lxc lxc-download lxc-templates gettext xz bridge
RUN \
	echo "lxc.lxcpath = /data" > /etc/lxc/lxc.conf && \
	echo "root:1000000:65536" >> /etc/subuid && \
	echo "root:1000000:65536" >> /etc/subgid && \
	echo "PS1='\\h (type lxcc to enter container) \\w # '" > /etc/ashrc

COPY fs /
VOLUME /data /vol
CMD ["/bin/entrypoint.sh"]
