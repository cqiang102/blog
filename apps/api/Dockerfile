FROM ghcr.io/graalvm/native-image-community:21-muslib AS build

WORKDIR /app

COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
RUN chmod +x mvnw
RUN ./mvnw dependency:go-offline -B

COPY src src
RUN ./mvnw -Pnative native:compile -DskipTests -B

FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=build /app/target/blog-api blog-api

EXPOSE 8080

ENTRYPOINT ["/app/blog-api"]
