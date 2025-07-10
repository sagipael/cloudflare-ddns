
# Cloudflare Dynamic DNS
Cloudflare tunnel + DDNS + LetsEncrypt cert generator

## Parameters

| Parameter | Function | Comment |
| :----: | --- | --- |
| `TUNNEL_TOKEN` | Cloudflare Tunnel token | Follow instructions below |
| `TOKEN` | Cloudflare account token, with edit permissions for DNS | [API Token](https://dash.cloudflare.com/profile/api-tokens) |
| `A_RECORD` | A record for Dynamic DNS | example: dynamic|
| `DOMAIN` | Your managed Domain name in cloudflare | example: example.com |
| `SCHEDULE` | set time for recurrent ddns update  | examples: 1h/1d/2mo|
| `SSL` | Enable/disable wildcard certificate generator | true/false |



## To get the Cloudflare Tunnel token, follow these steps:

Log in to your [Cloudflare Dashboard](https://one.dash.cloudflare.com/).
Navigate to the Zero Trust
Select Tunnels from the navigation menu.
Click on Create a Tunnel.
Follow the on-screen instructions to name your tunnel and select your desired configuration.
Once the tunnel is created, Cloudflare will provide a Tunnel Token. Copy this token and paste it into the .env file under TUNNEL_TOKEN.
