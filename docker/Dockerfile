FROM asmh1989/android-sdk

# RUN \
#   curl http://192.168.10.64:3771/fire/bmdm > /usr/bin/bmdm && \
#   chmod a+x /usr/bin/bmdm

# RUN \
#   curl http://192.168.10.64:3771/fire/ZKM.jar > /lib/ZKM.jar

COPY bmdm /usr/bin/bmdm
RUN chmod +x /usr/bin/bmdm
COPY ZKM.jar /lib/ZKM.jar
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]