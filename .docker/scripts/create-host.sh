#!/bin/bash

#
# This will automate the setup of a DigitalOcean droplet. There are still a few things
# that must be manually done:
#  1. Add the circleci private key to the project in circleci
#     https://circleci.com/docs/api/#create-ssh-keys
#  2. Create a digitalocean api token and add it to the circleci project
#     as an environment variable
#  3. Create the database
#     https://developers.digitalocean.com/documentation/v2/#create-a-new-database-cluster
#  4. Add the droplet to the list of trusted sources to the managed database
#     https://developers.digitalocean.com/documentation/v2/#update-firewall-rules--trusted-sources--for-a-database-cluster
#
# Params:
#  Digital Ocean token
#  Droplet name
#

set -e

token="$1"
droplet_name="$2"

if [[ -z "${token}" ]]; then
    # token must be passed in as an argument
    echo "No token defined."
    exit 1
fi

if [[ -z "${droplet_name}" ]]; then
    # droplet name must be passed in as an argument
    echo "No droplet name defined."
    exit 1
fi

# Get the current droplets
droplets_json=$(docker run --rm --env=DIGITALOCEAN_ACCESS_TOKEN=${token} digitalocean/doctl compute droplet list -o json)
# Get the existing droplets and put into an array
existing_droplets=$(echo ${droplets_json} | jq .[].name)

# Search the array
if [[ " ${existing_droplets[@]} " =~ "${droplet_name}" ]]; then
    # The droplet we were going to create has already been created
    echo "droplet ${droplet_name} already exists"
    exit 0
fi

# If we are here, the server doesn't exist yet.
# Lets work our magic and create the server.
# Since the server does not exist yet, we are assuming everything else needs to be created.

# Create a volume
volume_json=$(docker run --rm --env=DIGITALOCEAN_ACCESS_TOKEN=${token} digitalocean/doctl compute volume create ${droplet_name} --size 1GiB --fs-type ext4 --region sfo2 --tag volume,cardtechie,cardalmanac,prod,cardalmanac-com -o json || echo "error creating volume")
volume_id=$(echo ${volume_json} | jq .[0].id)
echo "Volume ${volume_id} created"

# Create the droplet
create_droplet_json=$(docker run --rm --env=DIGITALOCEAN_ACCESS_TOKEN=${token} digitalocean/doctl compute droplet create ${droplet_name} --region sfo2 --image 106820420 --size s-1vcpu-1gb --enable-monitoring --tag-names app,cardtechie,docker,nginx,laravel,prod,cardalmanac,cardalmanac-com,wordpress,tradingcardapi --volumes ${volume_id} -o json)
droplet_id=$(echo ${create_droplet_json} | jq .[0].id)
echo "Droplet ${droplet_id} created"

# The response from creating the droplet does not include the IP address so we have to look it up here
# we can't get the IP address until the droplet is active so we need to
droplet_ip_address=null
while [ "${droplet_ip_address}" = null ]; do
    droplet_json=$(docker run --rm --env=DIGITALOCEAN_ACCESS_TOKEN=${token} digitalocean/doctl compute droplet get ${droplet_id} -o json)
    droplet_ip_address=$(echo ${droplet_json} | jq .[0].networks.v4[0].ip_address)
    if [[ "${droplet_ip_address}" == null ]]; then
        sleep 5
    fi
done
droplet_ip_address=$(echo ${droplet_ip_address} | xargs echo)
echo "IP Address: ${droplet_ip_address}"

# Add the droplet to the cardtechie project
docker run --rm --env=DIGITALOCEAN_ACCESS_TOKEN=${token} digitalocean/doctl projects resources assign 414b5efb-debd-4e91-bc5f-b81949522392 --resource=do:droplet:${droplet_id}

# Create the A DNS records for the new site
docker run --rm --env=DIGITALOCEAN_ACCESS_TOKEN=${token} digitalocean/doctl compute domain records create --record-type A --record-name @ --record-data ${droplet_ip_address} cardalmanac.com

# Mount the volume
# When we attempt to connect to our new droplet, the connection will timeout until the server is ready
connect=false
while [ "${connect}" = false ]; do
    connect=true
    ssh -o ConnectTimeout=5 github@${droplet_ip_address} "mkdir -p /mnt/cardalmanac; mount -o discard,defaults /dev/disk/by-id/scsi-0DO_Volume_cardalmanac /mnt/cardalmanac; echo /dev/disk/by-id/scsi-0DO_Volume_cardalmanac /mnt/cardalmanac ext4 defaults,nofail,discard 0 0 | sudo tee -a /etc/fstab" || connect=false
    if [[ "${connect}" == false ]]; then
        sleep 20
    fi
done
