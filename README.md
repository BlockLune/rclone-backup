# rclone-backup

Backup data with [`rclone`](https://rclone.org).

## Usage

You need to install `rclone` and configure it first. Check the [rclone documentation](https://rclone.org/docs/) for more information.

Then, download the backup script and make it executable:

```bash
curl -O https://raw.githubusercontent.com/BlockLune/rclone-backup/refs/heads/main/backup.sh
chmod +x backup.sh
```

Back up your data with the following command:

```bash
./backup.sh SOURCE DESTINATION
```

You can use `--help` to see more options:

```text
Usage: backup.sh [OPTIONS] <src> <dest>

Backup directory using tar and rclone.

Options:
  --help                Show this help message
  --max-files=N         Maximum number of backup files to keep (default: 3, 0 for unlimited)
  --rclone-config=PATH  Specify rclone config file path

Arguments:
  src                   Source directory to backup
  dest                  Destination path (rclone remote)

Example:
  backup.sh /path/to/backup remote:backup/
  backup.sh --max-files=5 /path/to/backup remote:backup/
```

## Example Senario

I want to backup `/home/blocklune/docker_data` to my Cloudflare R2 storage. The bucket name is `rclone`, and the directory in it is `docker_data_backup`.

My rclone configuration file is located at `/root/.config/rclone/rclone.conf`.

```text
[r2]
type = s3
provider = Cloudflare
access_key_id = MY_ACCESS_KEY_ID
secret_access_key = MY_SECRET_ACCESS_KEY
region = auto
endpoint = https://MY_ENDPOINT
```

I will run the following command to add a new backup job:

```bash
sudo crontab -e
```

And add the following line to the crontab file (run every Sunday, Tuesday, and Friday at 4:00 AM):

```text
0 4 * * 0,2,5 /home/blocklune/rclone-backup/backup.sh /home/blocklune/docker_data/ r2:rclone/docker_data_backup/ >> /home/blocklune/rclone-backup/backup.log 2>&1
```

## References

- [rclone备份文件至cloudflare的r2 – 栋dong的个人站点](https://itdong.me/linux-to-cloudflarer2-with-rclone/)
- [利用 Rclone 对服务器备份 - Yunfi](https://yfi.moe/post/rclone-backup)
