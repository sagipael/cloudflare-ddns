
# Cloudflare Dynamic DNS
Cloudflare tunnel + DDNS + LetsEncrypt cert generator

## Parameters

| Parameter | Function | Comment |
| :----: | --- | --- |
| `CF_TUNNEL_TOKEN` | Cloudflare Tunnel token | Follow instructions below |
| `CF_DNS_TOKEN` | Cloudflare account token, with **edit** permissions for DNS | [API Token](https://dash.cloudflare.com/profile/api-tokens) |
| `CF_A_RECORD` | A record for Dynamic DNS | example: dynamic|
| `CF_DOMAIN` | Your managed Domain name in cloudflare | example: example.com |
| `SCHEDULE` | set time for recurrent ddns update  | examples: 1h/1d/2mo|
| `SSL` | Enable/disable wildcard certificate generator | true/false |
| `MAIL` | Set mail address for ssl certificate | script will try to fetch the mail from api |



## To get the Cloudflare Tunnel token, follow these steps:
(CF_TUNNEL_TOKEN)<br>
Log in to your [Cloudflare Dashboard](https://one.dash.cloudflare.com/).<br>
Navigate to the Zero Trust<br>
Select Tunnels from the navigation menu.<br>
Click on Create a Tunnel.<br>
Follow the on-screen instructions to name your tunnel and select your desired configuration.<br>
Once the tunnel is created, Cloudflare will provide a Tunnel Token. Copy this token and paste it into the .env file under TUNNEL_TOKEN.


## Notes
* CF_A_RECORD must be created in advance
* certbot runs every day at 3AM (CRON_TIME='0 3 * * *' )<br>
to change it, set cron pattern as CRON_TIME


