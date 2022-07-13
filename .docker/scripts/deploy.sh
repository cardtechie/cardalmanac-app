#!/bin/bash

function onerror() {
    echo "------FAILURE---------------------"
    echo "Deployment failed"
    exit 1
}

set -ex

trap onerror EXIT

start="$(date +%s)"

if [[ ! -d "/var/www/cardalmanac.com" ]]; then
    sudo mkdir -p /var/www/cardalmanac.com
    sudo chown github:deploy /var/www/cardalmanac.com
fi

# Create the symlink for storage if it doesn't exist or it's broken
if [[ ! -L /var/www/cardalmanac.com/storage || ! -e /var/www/cardalmanac.com/storage ]]; then
    sudo mkdir -p /mnt/cardalmanac/storage
    sudo rm -rf /var/www/cardalmanac.com/storage
    sudo chown -Rv github:www-data /mnt/cardalmanac/storage
    ln -s /mnt/cardalmanac/storage /var/www/cardalmanac.com/storage
fi

# Create the symlink for certs if it doesn't exist or it's broken
if [[ ! -L /var/www/cardalmanac.com/certs || ! -e /var/www/cardalmanac.com/certs ]]; then
    sudo mkdir -p /mnt/cardalmanac/certs
    sudo rm -rfv /var/www/cardalmanac.com/certs
    ln -s /mnt/cardalmanac/certs /var/www/cardalmanac.com/certs
fi

cp ~/deploy/cardalmanac.env /var/www/cardalmanac.com/.env
cp ~/deploy/.docker/prod.docker-compose.yaml /var/www/cardalmanac.com/docker-compose.yaml
cd /var/www/cardalmanac.com

# Start the container
docker-compose pull
docker-compose up -d

docker system prune -af

end="$(date +%s)"

echo "------SUCCESS---------------------"
echo "Deployment complete in "$(expr $end - $start)" seconds"

trap - EXIT
exit 0
