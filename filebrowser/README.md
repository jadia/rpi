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



## Change credentials

```bash
docker exec -ti filebrowser sh
```

```bash
# List all users
./filebrowser -d '/database/filebrowser.db' users ls
# Modify the credentials
./filebrowser -d '/database/filebrowser.db' users update admin --password admin
```