Name:           cashier-system
Version:        %{version}
Release:        1%{?dist}
Summary:        Premium Stationery POS System for Egyptian shops
License:        Proprietary
URL:            https://github.com/OmarAdel10/cashier_system
Source0:        %{name}-%{version}.tar.gz

# Build dependencies
BuildRequires:  flutter >= 3.12.0
BuildRequires:  dotnet-sdk-8.0
BuildRequires:  desktop-file-utils
BuildRequires:  libappstream-glib

# Runtime dependencies
Requires:       cups >= 2.4
Requires:       libcups2 >= 2.4
Requires:       gtk3 >= 3.24
Requires:       libsecret-1-0
Requires:       fontconfig
Requires:       libX11
Requires:       libxkbcommon
Requires:       libwayland-client0
Requires:       hicolor-icon-theme

# Optional: for thermal printer raw USB access
Requires:       udev

%description
A premium, ultra-responsive, offline-first POS engine for Egyptian stationery shops.
Includes Flutter desktop application and .NET PrintServer sidecar for thermal receipt
printing via CUPS, with full Arabic RTL support.

%prep
%autosetup -p1

%build
# 1. Flutter Linux release build
export ED25519_PUBKEY_HEX=%{ed25519_pubkey_hex}
flutter build linux --release --dart-define=ED25519_PUBKEY_HEX=%{ed25519_pubkey_hex}

# 2. PrintServer.Linux self-contained build
cd PrintServer.Linux
dotnet publish PrintServer.Linux.csproj -c Release -r linux-x64 --self-contained true -o ../build/linux/x64/release/bundle/PrintServer

%install
rm -rf %{buildroot}

# Main application
mkdir -p %{buildroot}/opt/cashier-system
cp -r build/linux/x64/release/bundle/* %{buildroot}/opt/cashier-system/

# Binary symlink
mkdir -p %{buildroot}/usr/bin
ln -s /opt/cashier-system/cashier-system %{buildroot}/usr/bin/cashier-system

# Desktop entry
mkdir -p %{buildroot}/usr/share/applications
cat > %{buildroot}/usr/share/applications/cashier-system.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Cashier System
GenericName=POS System
Comment=Premium Stationery POS for Egyptian shops
Exec=cashier-system
Icon=cashier-system
Terminal=false
Categories=Office;Commerce;
StartupNotify=true
StartupWMClass=cashier_system
EOF

# Icon
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps
cp assets/icon/pos_cashier_icon.png %{buildroot}/usr/share/icons/hicolor/256x256/apps/cashier-system.png

# AppStream metadata (optional, for software centers)
mkdir -p %{buildroot}/usr/share/metainfo
cat > %{buildroot}/usr/share/metainfo/cashier-system.metainfo.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>cashier-system</id>
  <name>Cashier System</name>
  <summary>Premium Stationery POS for Egyptian shops</summary>
  <description>
    <p>A premium, ultra-responsive, offline-first POS engine for Egyptian stationery shops.</p>
  </description>
  <categories>
    <category>Office</category>
    <category>Commerce</category>
  </categories>
  <icon type="cached">cashier-system</icon>
  <launchable type="desktop-id">cashier-system.desktop</launchable>
</component>
EOF

# Optional: systemd user service for PrintServer auto-start
mkdir -p %{buildroot}/usr/lib/systemd/user
cat > %{buildroot}/usr/lib/systemd/user/cashier-printserver.service <<EOF
[Unit]
Description=Cashier System Print Server
After=network.target cups.service
Wants=cups.service

[Service]
Type=simple
ExecStart=/opt/cashier-system/PrintServer/PrintServer.Linux
Restart=on-failure
RestartSec=5
Environment=ASPNETCORE_URLS=http://127.0.0.1:5150
Environment=DOTNET_hostBuilder:reloadConfigOnChange=false

[Install]
WantedBy=default.target
EOF

%post
# Update desktop database
update-desktop-database %{_datadir}/applications &> /dev/null || :

# Update icon cache
gtk-update-icon-cache -f %{_datadir}/icons/hicolor &> /dev/null || :

# AppStream
appstreamcli refresh-cache force &> /dev/null || :

%postun
update-desktop-database %{_datadir}/applications &> /dev/null || :
gtk-update-icon-cache -f %{_datadir}/icons/hicolor &> /dev/null || :

%files
/opt/cashier-system/
/usr/bin/cashier-system
/usr/share/applications/cashier-system.desktop
/usr/share/icons/hicolor/256x256/apps/cashier-system.png
/usr/share/metainfo/cashier-system.metainfo.xml
/usr/lib/systemd/user/cashier-printserver.service

%changelog
* %{version_date} %{packager} - %{version}-1
- Initial RPM release