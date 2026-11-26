# Replace VERSION (e.g., v26.4.0 or v26.2.12) and ARCH (linux-amd64 or linux-arm64)
VERSION="v26.4.0"
ARCH="linux-amd64"

curl -O https://cockroachdb.com{VERSION}.${ARCH}.tgz
tar -xzf cockroach-${VERSION}.${ARCH}.tgz
sudo cp -i cockroach-${VERSION}.${ARCH}/cockroach /usr/local/bin/

# Install GEOS libraries for spatial/GIS features
sudo mkdir -p /usr/local/lib/cockroach
sudo cp -i cockroach-${VERSION}.${ARCH}/lib/* /usr/local/lib/cockroach/

# Verify installation
cockroach version
