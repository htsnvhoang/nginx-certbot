#!/bin/bash
set -m
# set -m command allow enable foreground job control

default_letsencript_path="/etc/letsencrypt"
default_cerbot_path="/var/www/certbot"
rsa_key_size=4096
origin_folder_config="/nginx-config"
final_folder_config="/nginx-config-final"
email="${SSL_EMAIL:-hoangnv2nf@gmail.com}"

init() {
    mkdir -p $origin_folder_config
    mkdir -p $default_cerbot_path
}
job_renew_ssl() {
    local is_auto_renew_ssl=`echo $AUTO_RENEW`
    if [ $is_auto_renew_ssl = '1' ] || [ $is_auto_renew_ssl = 1 ]; then
        echo -e '0 0 * * 5 /cronjob-renew.sh > /var/log/renew_job.log' >> /crontab.txt
        chmod a+x /cronjob-renew.sh
        /usr/bin/crontab /crontab.txt
        rm /crontab.txt
        # Start cron deamon in backgroud
        /usr/sbin/crond -b -l 8
        echo "### Start job auto renew ssl"
    fi
}
# Replace enviroment variable from docker to nginx config file
map_env() {
    echo "### Start map env variable nginx file config"
    local envs=$(env | cut -d'=' -f1)
    local substr=$(printf '${%s} ' $envs)
    local folder_nginx_config=$(ls $origin_folder_config/*.conf)
    mkdir -p "$final_folder_config"

    for file_config in $folder_nginx_config; do
        local array_temp=(${file_config//\// })
        local file_name=${array_temp[${#array_temp[@]}-1]}
        envsubst "$substr" < "$file_config" > "$final_folder_config/$file_name"
    done
}
download_param() {
    if [ ! -e "$default_letsencript_path/options-ssl-nginx.conf" ] || [ ! -e "$default_letsencript_path/ssl-dhparams.pem" ]; then
        echo "### Downloading recommended TLS parameters ..."
        mkdir -p $default_letsencript_path
        curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf >"$default_letsencript_path/options-ssl-nginx.conf"
        curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem >"$default_letsencript_path/ssl-dhparams.pem"
        echo
    fi
}
create_dummy_certificate() {
    echo "### Creating dummy certificate for $1"
    openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1 \
        -keyout "$2/privkey.pem" \
        -out "$2/fullchain.pem" -subj "/CN=localhost"
    echo
}
delete_dummy_certificate() {
    echo "### Deleting dummy certificate for $1 ..."
    rm -Rf $default_letsencript_path/live/$1 &&
        rm -Rf $default_letsencript_path/archive/$1 &&
        rm -Rf $default_letsencript_path/renewal/$1.conf
    echo
}
gen_ssl() {
    local domain_name=$1
    local file_config_name=$2
    local path="$default_letsencript_path/live/$domain_name"

    echo "### Handle ssl for domain: $domain_name"
    
    if [ -d $path ]; then
        # renew ssl
        echo "### Renew certificate"
        certbot renew
        nginx -s reload
    else
        mkdir -p $path
        create_dummy_certificate $domain_name $path

        if [ ! -e /var/run/nginx.pid ]; then
            echo "### Starting nginx ..."
            nginx -g 'daemon off;' &
            sleep 2
        fi

        cp "$final_folder_config/$file_config_name" "/etc/nginx/conf.d/$file_config_name"
        nginx -t
        nginx -s reload

        delete_dummy_certificate $domain_name

        echo "### Requesting Let's Encrypt certificate for $domain_name ..."
        local domain_args=" -d $domain_name -d www.$domain_name"
        yes | certbot certonly --webroot -w $default_cerbot_path \
            --email $email \
            $domain_args \
            --rsa-key-size $rsa_key_size \
            --agree-tos \
            --force-renewal
        echo "\n"
        nginx -s reload

        echo "### Finish certificate for $domain_name"
    fi
}
group_domain() {
    local config_ssl_groups=$(env | grep "^CONFIG_SSL_GROUP_" | cut -d '=' -f 1)
    for group_config in $config_ssl_groups; do
        local _temp=$(printf '%s' "${!group_config}")
        local _domain_name=$(echo $_temp | cut -d ";" -f 1)
        local _config_file_name=$(echo $_temp | cut -d ";" -f 2)

        gen_ssl $_domain_name $_config_file_name
    done
    fg
}

main() {
    init
    job_renew_ssl
    map_env
    download_param
    group_domain
}

main
