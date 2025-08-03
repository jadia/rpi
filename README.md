# Raspberry Pi
Collection of resources dedicated to my Raspberry Pi 4B 8GB RAM set up.

## Raspberry Pi SD Card Backup, Shrink, and Restore with Docker PiShrink

### 1. Backup SD Card
Insert the SD card into your Ubuntu laptop and find its device:
```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
```
Example output might show the SD card as `/dev/sda` (\~32GB).

Create a raw image:
```bash
sudo dd if=/dev/sda of=~/pi32gb.img bs=4M status=progress conv=fsync
sync
```

### 2. Setup PiShrink with Docker
Add an alias to run PiShrink via Docker:
```bash
echo "alias pishrink='docker run -it --rm --privileged=true -v \$(pwd):/workdir pishrink'" >> ~/.bashrc
source ~/.bashrc
```
* `--privileged` is required because PiShrink mounts partitions via loop devices and resizes filesystems.
* `-v $(pwd):/workdir` mounts the current directory to `/workdir` in the container.

### 3. Shrink and Compress Image
Move to the folder containing the `.img` file:
```bash
cd ~/backup_HDD
```
Run PiShrink with maximum compression and verbose output:
```bash
pishrink -v -a -Z pi32gb.img
```
**Flags:**
* `-v` verbose output
* `-a` use all CPU cores for compression
* `-Z` compress with xz for best compression

The result will be `pi32gb.img.xz`, much smaller than the original image.

The image will auto-expand to the full SD card size on first boot.

### 4. Restore to a New SD Card
Insert the new SD card (for example, 128GB) and check its device:
```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
```
Write the compressed image directly to the SD card:
```bash
xzcat pi32gb.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
sync
```
Replace `/dev/sdX` with the correct SD card device.

### 5. Verify After Boot
On the Raspberry Pi:
```bash
df -h /
```
The root filesystem should now show the full capacity of the new SD card.

## **Upgrade Raspberry Pi SD Card to a Larger Size**
Follow these steps to clone a smaller SD card to a larger one and expand the filesystem to use all space. 
Tested on **Ubuntu 20.04.6 LTS x86_64** with **Raspberry Pi 4B running Ubuntu 22.10 aarch64**.

### **1. Identify SD Cards**
1. Insert the old SD card (32GB) into your laptop.
2. Check its device name:
```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
```
Example output: `/dev/sda` (\~29GB).

### **2. Backup Old SD Card**
Create an image of the existing SD card:
```bash
sudo dd if=/dev/sdX of=~/pi32gb.img bs=4M status=progress conv=fsync
sync
```
* Replace `sdX` with your old card (e.g., `/dev/sda`).

### **3. Write Image to New SD Card**
1. Insert the new larger SD card (e.g., 128GB).
2. Verify its device name with `lsblk` (\~117GB).
3. Write the image:
```bash
sudo dd if=~/pi32gb.img of=/dev/sdY bs=4M status=progress conv=fsync
sync
```
* Replace `sdY` with your new card.

### **4. Resize the Root Partition**
Use **gparted** on the laptop:
```bash
sudo apt install gparted
sudo gparted
```
1. Select the new SD card.
2. Resize the **last/root partition** to fill all unallocated space.
3. Apply changes.

### **5. Verify Expansion**
**On Laptop:**
```bash
sudo mkdir -p /mnt/sdroot
sudo mount /dev/sdY2 /mnt/sdroot
df -h /mnt/sdroot
sudo umount /mnt/sdroot
```
**On Raspberry Pi after boot:**
```bash
df -h /
```
You should now see **full 128GB (≈117GB usable)**.
