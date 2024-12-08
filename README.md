# misskey-backup
o1に書かせたのでちゃんと動くのかは知りませんが、わたしの環境では動いてます。

# Requirements
* https://github.com/glotlabs/gdrive

# memo
```
sudo usermod -aG docker user
newgrp docker
0 4 * * * /home/misskey/backup.sh
```
