# Ollama for Raspberry Pi

We have fixed the v0.6.16 because the container would get stuck on a boot loop 
on versions greater than the one we fixed.

Use can use [docker-compose-dual-container.yml](ollama/docker-compose-dual-container.yml) 
if you wish to separately host the web-ui and ollama API.

You can use the `codegemma:2b` model. 