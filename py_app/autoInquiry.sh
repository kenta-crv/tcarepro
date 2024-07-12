cd /home/smart/webroot/tcarepro/app
export INQUIRY_MODE=DEBUG
PATH=/home/smart/.pyenv/shims/python3:/home/smart/.pyenv/shims/python3:/home/smart/.pyenv/shims:/home/smart/.pyenv/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/home/smart/.anyenv/envs/rbenv/shims:/home/smart/.anyenv/envs/rbenv/bin:/home/smart/.anyenv/envs/nodenv/shims:/home/smart/.anyenv/envs/nodenv/bin:/opt/anyenv/bin:/home/smart/.local/bin:/home/smart/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/var/lib/snapd/snap/bin
rm /opt/webroot/tcarepro/tmp/exported_data.csv
bundle exec rails runner /home/smart/work/exportCsv.rb
python /home/smart/webroot/tcarepro/py_app/inqLinux.py

