ip a > check.txt
#### tạo ra file "squid_config_generated.txt" từ file check.txt
input_file="check.txt"
output_file="squid_config_generated.txt"
num_lines=$(grep -c "inet6.*\/64" "$input_file")

if [ "$num_lines" -eq 0 ]; then
  echo "Không có dòng nào chứa \"inet6\" và \"/64\" trong file \"$input_file\"."
  exit 1
fi

FIRST_PORT=3128
echo "" > "$output_file"
current_port=$FIRST_PORT

http_ports=""
acl_ports=""
tcp_outgoing_addresses=""

while IFS= read -r line; do
  if [[ $line =~ inet6.*\/64 ]]; then
    ipv6_address=$(echo "$line" | awk '{print $2}' | sed 's:/.*::')

    http_ports+="http_port $current_port
"
    acl_ports+="acl ip$((current_port - FIRST_PORT + 1)) localport $current_port
"
    tcp_outgoing_addresses+="tcp_outgoing_address $ipv6_address ip$((current_port - FIRST_PORT + 1))
"

    current_port=$((current_port + 1))
  fi
done < "$input_file"

# Write the configurations to the output file
{
  echo "$http_ports"
  echo "$acl_ports"
  echo "$tcp_outgoing_addresses"
  echo ""
} >> "$output_file"

echo "Đã tạo ra $num_lines cấu hình port trong file \"$output_file\"."


### tạo ra config file từ squid_config_generated.txt


SQUID_CONFIG_CONTENT=$(cat squid_config_generated.txt)
CONFIG_CONTENT="
#
# Recommended minimum configuration:
#

# Example rule allowing access from your local networks.
# Adapt to list your (internal) IP networks from where browsing
# should be allowed
acl localnet src 10.0.0.0/8     # RFC1918 possible internal network
acl localnet src 172.16.0.0/12  # RFC1918 possible internal network
acl localnet src 192.168.0.0/16 # RFC1918 possible internal network
acl localnet src fc00::/7       # RFC 4193 local private network range
acl localnet src fe80::/10      # RFC 4291 link-local (directly plugged) machines

acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl CONNECT method CONNECT

http_access allow all

$SQUID_CONFIG_CONTENT

# Uncomment and adjust the following to add a disk cache directory.
#cache_dir ufs /var/spool/squid 100 16 256
# Leave coredumps in the first cache dir
coredump_dir /var/spool/squid

#
# Add any of your own refresh_pattern entries above these.
#
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
"

# In xuống tệp tin mới hoặc ghi vào tệp cần thiết
echo "$CONFIG_CONTENT" > /etc/squid/squid.conf
systemctl stop firewalld
systemctl restart squid
