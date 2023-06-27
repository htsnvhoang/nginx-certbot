# nginx-certbot
You can pull it from docker hub: `https://hub.docker.com/r/nvhoanghts/nginx-certbot`.
## Required config:
- Map file config nginx to volume path /nginx-config container
> Ex: ./sample-config-nginx/:/nginx-config/
- Set env variable for domain you want to create certificate with fomat:

>CONFIG_SSL_GROUP_{order number of multiple domain}={domain_name};{name_file_config}
>Example: CONFIG_SSL_GROUP_1=yourdomain.com;server_api.conf

## Other config env (optional)
- SSL_EMAIL: email for certbot request Let's Encrypt certificate
- AUTO_RENEW: default = 1 (enable job to auto renew certificate, run on every Friday at 00h:00)