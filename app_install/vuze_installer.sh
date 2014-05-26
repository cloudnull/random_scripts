#!/usr/bin/env bash
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Download the latest VUZE and install it in Opt on your system

# This will create a desktop entry for VUZE and should setup 
# all on the needed bits on the disk to run vuze normally.
# This should work on all desktop linux however I've only tested 
# it on KDE, becasue I don't run other desktops.


set -e -v -u

if [ ! "$(which java)" ];then
  echo "Java was not found on the system within your PATH"
  echo "Here is your PATH: ${PATH}"
  exit 1
fi

sudo apt-get -y install wget || sudo yum -y install wget

echo "Getting the Vuze Files"
wget http://cf1.vuze.com/files/VuzeInstaller.tar.bz2 -O /tmp/VuzeInstaller.tar.bz2
sudo tar jxvf VuzeInstaller.tar.bz2 -C /opt/

if [ ! "$(grep vuze /etc/passwd)" ];then
  echo "Creating vuze user"
  sudo useradd --shell /bin/false \
               --system --comment "vuze system user" \
               --no-create-home vuze
fi

echo "Creating link to vuze run script"
cat << EOF | sudo tee /opt/vuze/runvuze.sh
#!/usr/bin/env bash
/opt/vuze/vuze "\$*"
EOF

sudo chmod +x /opt/vuze/runvuze.sh
sudo ln -sf /opt/vuze/runvuze.sh /usr/bin/vuze


if [ -d "/usr/share/applications/" ];then
  # Create desktop entry
  cat << EOF | sudo tee /opt/vuze/vuze.desktop
[Desktop Entry]
Encoding=UTF-8
Categories=Java;Network;FileTransfer;P2P
Comment=Multimedia Bittorrent Client 
Exec=vuze %f
GenericName=Multimedia Bittorrent Client
Icon=vuze.png
MimeType=application/x-bittorrent;x-scheme-handler/magnet
Name=Vuze
Type=Application
EOF

  sudo ln -sf /opt/vuze/vuze.desktop /usr/share/applications/vuze.desktop
fi

echo "Changing Ownership of the Vuze Application"
sudo chown -R vuze:vuze /opt/vuze
sudo find /opt/vuze/ -type d -exec chmod 755 {} \;

