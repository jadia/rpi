# Filebrowser

```bash
mkdir -p ~/data/filebrowser/
touch ~/data/filebrowser/filebrowser.db
vim ~/data/filebrowser/filebrowser.json
```

The contents of the `json` file would be the following:
```json
{
  "port": 80,
  "baseURL": "",
  "address": "",
  "log": "stdout",
  "database": "/database/filebrowser.db",
  "root": "/srv"
}
```   
[Source](https://raw.githubusercontent.com/filebrowser/filebrowser/master/docker/root/defaults/settings.json)