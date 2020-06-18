FROM asmh1989/android-sdk


# gnupg2: https://stackoverflow.com/questions/50757647
RUN \
  apt-get -q update && apt-get install --no-install-recommends -y -q gnupg2 curl git ca-certificates apt-transport-https openssh-client && \
  curl https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
  curl https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list && \
  apt-get update && \
  apt-get install dart && \
  rm -rf /var/lib/apt/lists/*

ENV DART_SDK /usr/lib/dart
ENV PATH $DART_SDK/bin:/root/.pub-cache/bin:$PATH

COPY docker/ZKM.jar /lib/ZKM.jar

WORKDIR /app

ADD pubspec.* /app/
RUN pub get
ADD . /app

ENTRYPOINT ["/usr/bin/dart", "bin/server.dart"]