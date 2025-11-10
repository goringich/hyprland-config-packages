#!/usr/bin/env bash
# ~/.config/hypr/scripts/fun.sh
# запускает cmatrix, bpytop и автоматически запускает starwars на telehack

TERMINAL="kitty"   # заменяй на свой терминал, например: alacritty, kitty, foot, kitty
# стартуем cmatrix и bpytop в отдельных окнах
$TERMINAL -e cmatrix &
sleep 0.25
$TERMINAL -e bpytop &
sleep 0.25

# используем expect для автоматического ввода "starwars" в telnet
# создаём временный expect-скрипт и запускаем его в отдельном терминале
EXPECT_SCRIPT=$(mktemp)
cat > "$EXPECT_SCRIPT" <<'EOF'
#!/usr/bin/expect -f
set timeout 20
spawn telnet telehack.com 23
# даём серверу время и отправляем команду starwars
sleep 1
send "starwars\r"
interact
EOF

# запускаем expect в новом окне (чтобы показать вывод пользователю)
$TERMINAL -e bash -c "expect $EXPECT_SCRIPT; rm -f $EXPECT_SCRIPT"
