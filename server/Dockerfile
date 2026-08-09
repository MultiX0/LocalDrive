# One image, one binary, several modes. The privilege boundary is the
# container each mode runs in, not the file on disk.
#
# The final stage is alpine rather than scratch because real pdf and video
# thumbnails need pdftoppm and ffmpeg on disk, and scratch has no filesystem to
# put them on. That is a deliberate trade of a few tens of megabytes for
# working previews on the two most common non-image types.

FROM golang:1.25-alpine AS build

ARG VERSION=dev
WORKDIR /src

RUN apk add --no-cache git ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# pure go sqlite driver, so there is no cgo linkage to worry about
ENV CGO_ENABLED=0 GOOS=linux
RUN go build -trimpath \
      -ldflags "-s -w -X main.version=${VERSION}" \
      -o /out/localdrive ./cmd/localdrive


FROM alpine:3 AS runtime

ARG VERSION=dev
LABEL org.opencontainers.image.title="Local Drive" \
      org.opencontainers.image.description="Self hosted file storage" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.licenses="MIT"

# ffmpeg and poppler for thumbnails; the rest are the tools the drive helper
# shells out to with fixed argument lists, and are only reachable in the
# container that runs that mode
RUN apk add --no-cache \
      ffmpeg poppler-utils ca-certificates tzdata \
      util-linux e2fsprogs e2fsprogs-extra xfsprogs btrfs-progs \
      dosfstools exfatprogs ntfs-3g fuse3 \
 && addgroup -g 10001 -S localdrive \
 && adduser -u 10001 -S -G localdrive localdrive \
 && mkdir -p /data/db /data/library /data/external \
 && chown -R localdrive:localdrive /data

# mergerfs is only in Alpine's testing repository, and only the drive helper
# uses it, to combine several drives into one library. Installing it from
# testing on a stable base is the reason this is a separate layer that is
# allowed to fail: a missing mergerfs disables combining and nothing else,
# which is a far better outcome than an image that will not build.
RUN apk add --no-cache \
      --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing \
      mergerfs \
 || echo "mergerfs unavailable, combining drives will be disabled"

COPY --from=build /out/localdrive /localdrive

# the server mode drops to an unprivileged user. the drive helper mode is the
# one that needs root, and compose gives only that service the capability.
USER localdrive:localdrive

ENV LISTEN_ADDR=:8080 \
    DB_PATH=/data/db/localdrive.sqlite \
    LIBRARY_PATH=/data/library \
    EXTERNAL_MOUNTS_PATH=/data/external

EXPOSE 8080

# the binary answers its own healthcheck, so the image needs no curl or wget
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["/localdrive", "healthcheck"]

ENTRYPOINT ["/localdrive"]
CMD ["serve"]
