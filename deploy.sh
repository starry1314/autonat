#!/bin/bash

echo "[1/5] 安裝 socat..."
if ! command -v socat &>/dev/null; then
    if command -v yum &>/dev/null; then
        yum install -y socat
    elif command -v dnf &>/dev/null; then
        dnf install -y socat
    elif command -v apt &>/dev/null; then
        apt update && apt install -y socat
    else
        echo "[ERROR] 無法自動安裝 socat。" >&2
        exit 1
    fi
fi

echo "[2/5] 建立轉發腳本..."
mkdir -p /opt
cat > /opt/port_forward.sh << 'EOF'
#!/bin/bash
if ! command -v socat &>/dev/null; then
    echo "[ERROR] socat 未安裝。" && exit 1
fi

RULE_FILE="/opt/rules.txt"
[ ! -f "$RULE_FILE" ] && echo "[ERROR] 缺少 $RULE_FILE" && exit 1

# 修正換行符號
sed -i 's/\r$//' "$RULE_FILE"

# 移除舊規則
pkill -f 'socat TCP-LISTEN'
pkill -f 'socat UDP-LISTEN'

echo "[INFO] 套用新轉發規則..."
while read -r port host; do
    [[ -z "$port" || -z "$host" || "$port" =~ ^# ]] && continue
    echo "[FORWARD] $port -> $host:$port"
    nohup socat TCP-LISTEN:$port,reuseaddr,fork TCP:$host:$port >/dev/null 2>&1 &
    nohup socat UDP-LISTEN:$port,reuseaddr,fork UDP:$host:$port >/dev/null 2>&1 &
done < "$RULE_FILE"
EOF

chmod +x /opt/port_forward.sh

echo "[3/5] 建立 systemd 自動啟動..."
cat > /etc/systemd/system/port_forward.service << EOF
[Unit]
Description=Port Forward Service
After=network.target

[Service]
ExecStart=/opt/port_forward.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now port_forward.service

echo "[4/5] 建立空白規則檔 /opt/rules.txt"
touch /opt/rules.txt

echo "[5/5] 部署完成！"
echo "📌 請編輯 /opt/rules.txt 加入規則，每行格式為："
echo "    37122 tc-0406-a1-kw.nxinternet.uk"
echo "然後執行： systemctl restart port_forward.service"
