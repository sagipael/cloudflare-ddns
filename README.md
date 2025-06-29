
# Cloudflare Dynamic DNS
Cloudflare tunnel + DDNS + LetsEncrypt cert generator

## Parameters

| Parameter | Function | Comment |
| :----: | --- | --- |
| `TUNNEL_TOKEN` | Cloudflare Tunnel token | will add link |
| `TOKEN` | Cloudflare account token, with edit permissions for DNS | will add link |
| `A_RECORD` | A record for Dynamic DNS | example: dynamic|
| `DOMAIN` | Your managed Domain name in cloudflare | example: example.com |
| `SCHEDULE` | set time for recurrent ddns update  | examples: 1h/1d/2mo|
| `SSL` | Enable/disable wildcard certificate generator | true/false |


