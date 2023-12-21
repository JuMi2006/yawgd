FROM perl:5.32

COPY /etc /etc
COPY /usr /usr

RUN apt-get update -y
RUN apt-get install -y libmath-round-perl libmath-basecalc-perl librrds-perl libproc-pid-file-perl libproc-daemon-perl librrds-perl
RUN chmod +x /usr/sbin/yawgd.pl

CMD ["/usr/bin/perl", "/usr/sbin/yawgd.pl", "-d"]