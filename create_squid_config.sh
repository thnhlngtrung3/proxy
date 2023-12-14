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
