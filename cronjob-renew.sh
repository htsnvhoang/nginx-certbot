#!/bin/bash

certbot renew
sleep 1
nginx -s reload

date=`date`
echo "$date >> Done certbot renew & reload nginx" 