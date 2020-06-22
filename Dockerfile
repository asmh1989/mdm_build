FROM asmh1989/android-sdk:dart

WORKDIR /app

ADD pubspec.* /app/
RUN pub get
ADD . /app

ENTRYPOINT ["/usr/bin/dart", "bin/server.dart"]