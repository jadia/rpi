# Jellyfin

```bash
sudo apt install ntfs-3g -y
```

```bash
#sudo vim /etc/fstab
#ext4
UUID=feea3ffb-a45f-4fb7-8cf7-6f5b9fa9ef03 /mnt/64gb ext4 defaults,auto,users,rw,nofail,x-systemd.device-timeout=20 0 0
#ntfs
UUID=426973B40FC33521 /mnt/ssd ntfs-3g defaults,auto,users,rw,nofail,x-systemd.device-timeout=20 0 0
```